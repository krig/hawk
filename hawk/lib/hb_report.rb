# Copyright (c) 2009-2015 Tim Serong <tserong@suse.com>
# See COPYING for license.

# Redoing this:
#
# Generating:
# 1. generate to directory
# 2. write a <id>.meta.json which has all the metadata for hawk
#
# This includes:
#   1. start time
#   2. end time
#   3. map of node -> event list
#   4. map of resource -> resource event list
#   5. list of all transitions
#   6. for each transition;
#     6.1 details
#     6.2 cib
#     6.3 tags
#     6.4 logline count
#
# This way, once the generation is complete, hawk
# can very quickly display the info for that report.
# When listing reports, just search for *.meta.json,
# open it and read the info from there. That way, the
# index can actually show info like number of transitions.
#
# Uploading:
# 1. upload to packfile
# 2. unpack the packfile to directory
# 3. same as step 2 for generating
#
# This means uploading will need a second step which
# runs in parallel.
#
# Note: Make sure that only one unpack / annotation process
# can run at any given time.

class HbReport
  # Note: outfile, errfile are based off path passed to generate() -
  # don't use them prior to a generate run, or you'll get the wrong path.
  # Lastexit is global (this is freaky/dumb - everything should be based
  # off path, and callers need to be updated to understand this - this
  # will happen when we allow multiple hb_report runs, as
  # hb_reports_controller is what cares about lastexit)
  attr_reader :id
  attr_reader :path
  attr_reader :meta
  attr_reader :metafile
  attr_reader :outfile
  attr_reader :errfile
  attr_reader :lastexit

  def initialize(name = nil)
    @tmpbase = Rails.root.join('tmp', 'pids')
    @reports = Rails.root.join('tmp', 'reports')
    @tmpbase.mkpath unless @tmpbase.directory?
    @reports.mkpath unless @reports.directory?

    @pidfile = @tmpbase.join("report.pid").to_s
    @exitfile = @tmpbase.join("report.exit").to_s
    @timefile = @tmpbase.join("report.time").to_s
    if name
      @path = @reports.join(name).to_s
      @outfile = @reports.join("#{name}.stdout").to_s
      @errfile = @reports.join("#{name}.stderr").to_s
      @id = Digest::SHA1.hexdigest(@path)[0..8]
      @meta = "#{@id}.meta.json"
      @metafile = @reports.join(@meta).to_s
    else
      @path = nil
      @id = nil
      @meta = nil
      @metafile = nil
      @outfile = @tmpbase.join("report.stdout").to_s
      @errfile = @tmpbase.join("report.stderr").to_s
    end
    @lastexit = File.exists?(@exitfile) ? File.new(@exitfile).read.to_i : nil
  end

  def running?
    Util.child_active(@pidfile)
  end

  def delete
    FileUtils.remove_entry_secure(metafile) if File.exists?(metafile)
    FileUtils.remove_entry_secure(path) if File.exists?(path)
    FileUtils.remove_entry_secure(outfile) if File.exists?(outfile)
    FileUtils.remove_entry_secure(errfile) if File.exists?(errfile)
    [".tar.bz2", ".tar.gz", ".tar.xz"].each do |ext|
      ar = "#{@path}#{ext}"
      FileUtils.remove_entry_secure(ar) if File.exists? ar
    end
  end

  # Returns [filename, mimetype]
  def archive
    mimes = {
      ".tar.bz2" => "application/x-bzip",
      ".tar.gz" => "application/x-gz",
      ".tar.xz" => "application/x-xz"
    }
    mimes.keys.each do |ext|
      if File.exists? "#{@path}#{ext}"
        return [Pathname.new("#{@path}#{ext}"), mimes[ext]]
      end
      fn = "#{@path}.tar.bz2"
      out, err, status = Util.capture3 "tar", "--force-local", "-c", "-j", "-f", fn, @path
      return [Pathname.new(fn), mimes[".tar.bz2"]] if status.exitstatus == 0
    end
    [nil, nil]
  end

  # Returns [from_time, to_time], as strings.  Note that to_time might be
  # an empty string, if no to_time was specified when calling generate.
  def lasttime
    File.exists?(@timefile) ? File.new(@timefile).read.split(",", -1) : nil
  end

  # contents of errfile as array
  def err_lines
    err = []
    begin
      File.new(@errfile).read.split(/\n/).each do |e|
        next if e.empty?
        err << e
      end if File.exists?(@errfile)
    rescue ArgumentError => e
      # This will catch 'invalid byte sequence in UTF-8' (bnc#854060)
      err << "ArgumentError: #{e.message}"
    end
    err
  end

  # contents of errfile as array, with "INFO" lines stripped (e.g. for
  # displaying warnings after an otherwise successful run)
  def err_filtered
    err_lines.select do |e|
      !e.match(/( INFO: |(cat|tail): write error)/) && !e.match(/^tar:.*time stamp/)
    end
  end

  # Note: This assumes pidfile doesn't exist (will always blow away what's
  # there), so there's a possibility of a race (or lost hb_report status)
  # if two clients kick off generation at almost exactly the same time.
  # from_time and to_time (if specified) are expected to be in a sensible
  # format (e.g.: iso8601)
  def generate(from_time, to_time, all_nodes = true)

    [@outfile, @errfile, @exitfile, @timefile].each do |fn|
      File.unlink(fn) if File.exists?(fn)
    end
    @lastexit = nil

    f = File.new(@timefile, "w")
    f.write("#{from_time},#{to_time}")
    f.close
    pid = fork do
      args = ["-f", from_time]
      args.push("-t", to_time) if to_time
      args.push("-d") # Don't compress, leave the result in a directory
      args.push("-Z") # Remove destination directories if they exist
      args.push("-Q") # Requires a version of crm report which supports this
      args.push("-S") unless all_nodes
      args.push(@path)

      out, err, status = Util.run_as("root", "crm", "report", *args)
      f = File.new(@outfile, "w")
      f.write(out)
      f.close
      f = File.new(@errfile, "w")
      f.write(err)
      f.close

      # Record exit status
      ok = status.exitstatus

      # Generate <name>.meta.json
      if ok == 0
        ok = generate_meta_json
      end

      f = File.new(@exitfile, "w")
      f.write(ok)
      f.close

      # Delete pidfile
      File.unlink(@pidfile)
    end
    f = File.new(@pidfile, "w")
    f.write(pid)
    f.close
    Process.detach(pid)
  end

  # Returns a status code
  # writes error output to @errfile
  def generate_meta_json
    return 1 unless File.directory? path

    pelist = peinputs
    from_time = File.ctime path
    to_time = from_time

    if File.exists? @timefile
      ts = File.new(@timefile).read.split(",")
      from_time = ts[0]
      to_time = ts[1]
    end

    pe_cmd = [
      "# @@hawk@@ $$",
      "# @@hawk@@ info",
      "transition $$ nograph"
      "# @@hawk@@ show",
      "show $$",
      "# @@hawk@@ tags",
      "transition tags $$",
      "# @@hawk@@ end"
    ].join("\n")
    cmds = [].tap do |cmds|
      pelist.each do |pe|
        cmds.push pe_cmd.sub("$$", pe)
      end
    end.join("\n")

    transition_cmd(cmds)

    File.open(@metafile, 'w') do |f|
      f.write({
                id: @id,
                path: @path,
                meta: @meta,
                name: File.basename(@path),
                from_time: from_time,
                to_time: to_time,
                gen_output: File.read(@outfile),
                gen_error: File.read(@errfile),
                transitions: pelist,
                node_events: node_events,
                resource_events: resource_events
              }.to_json)
    end

    0
  end

  def transition_cmd(cmd)
    Util.capture3("/usr/sbin/crm", "history", stdin_data: "source #{@path}\n#{cmd}\n")
  end

  def info(transition)
    out, err, status = transition_cmd "transition #{transition} nograph"
    out.strip!
    out = _("No details available") if out.empty?
    err.insert(0, _("Error:") + "\n") unless status.exitstatus == 0
    [out, err]
  end

  def cib(transition)
    out, err, status = transition_cmd "show #{transition}"
    out
  end

  def node_events
    out, err, status = transition_cmd "node"
    out
  end

  def resource_events
    out, err, status = transition_cmd "resource"
    out
  end

  def tags(transition)
    out, err, status = transition_cmd "transition tags #{transition}"
    out.split
  end

  def logs(transition)
    out, err, status = transition_cmd "transition log #{transition}"
    out.strip!
    out = _("No details available") if out.empty?
    err.insert(0, _("Error:") + "\n") unless status.exitstatus == 0
    [out, err]
  end

  # Apparently we can't rely on the dot file existing in the hb_report, so we
  # just use ptest to generate it.  Note that this will fail if hacluster doesn't
  # have read access to the pengine files (although, this should be OK, because
  # they're created by hacluster by default).
  # Returns [success, data|error]
  def graph(transition, format = :svg)
    Rails.logger.debug "#{transition}, path=#{@path}"
    tpath = Pathname.new(@path).join(transition)
    require "tempfile"
    tmpfile = Tempfile.new("hawk_dot")
    tmpfile.close
    File.chmod(0666, tmpfile.path)
    out, err, status = Util.run_as('hacluster', 'crm_simulate', '-x', tpath.to_s, format == :xml ? "-G" : "-D", tmpfile.path.to_s)
    rc = status.exitstatus

    ret = [false, err]
    if rc != 0
      ret = [false, err]
    elsif format == :xml || format == :json
      ret = [true, File.new(tmpfile.path).read]
    else
      svg, err, status = Util.capture3("/usr/bin/dot", "-Tsvg", tmpfile.path)
      if status.exitstatus == 0
        ret = [true, svg]
      else
        ret = [false, err]
      end
    end
    tmpfile.unlink
    ret
  end

  # Returns the diff as a text or html string
  def diff(left, right, format = :html)
    format = "" unless format == :html
    out, err, status = transition_cmd "diff #{left} #{right} status #{format}"
    info = out + err

    info.strip!
    # TODO(should): option to increase verbosity level
    info = _("No details available") if info.empty?

    if status.exitstatus == 0
      if format == :html
        info += <<-eos
          <div class="row"><div class="col-sm-2">
          <table class="table">
            <tr><th>#{_('Legend')}:</th></tr>
            <tr><td class="diff_add">#{_('Added')}</th></tr>
            <tr><td class="diff_chg">#{_('Changed')}</th></tr>
            <tr><td class="diff_sub">#{_('Deleted')}</th></tr>
          </table>
          </div></div>
        eos
      end
    else
      info.insert(0, _("Error:") + "\n")
    end
    info
  end

  def peinput_version(path)
    nvpair = `CIB_file=#{path} cibadmin -Q --xpath "/cib/configuration//crm_config//nvpair[@name='dc-version']" 2>/dev/null`
    m = nvpair.match(/value="([^"]+)"/)
    return nil unless m
    m[1]
  end

  def peinputs
    source = path
    pcmk_version = nil
    m = `/usr/sbin/cibadmin -!`.match(/^Pacemaker ([^ ]+) \(Build: ([^)]+)\)/)
    pcmk_version = "#{m[1]}-#{m[2]}" if m

    [].tap do |peinputs|
      peinputs_raw, err, status = Util.capture3("/usr/sbin/crm", "history", stdin_data: "source #{source}\npeinputs\n")
      if status.exitstatus == 0
        peinputs_raw.split(/\n/).each do |fname|
          next unless File.exists?(fname)
          v = peinput_version fname
          if v && v != pcmk_version
            version = _("PE Input created by different Pacemaker version (%{version})" % { :version => v })
          elsif v != pcmk_version
            version = _("Pacemaker version not present in PE Input")
          else
            version = nil
          end
          peinputs.push(timestamp: File.mtime(fname).iso8601,
                        basename: File.basename(fname, ".bz2"),
                        filename: File.basename(fname),
                        path: fname.sub("#{path}/", ''),
                        node: fname.split(File::SEPARATOR)[-3],
                        version: version)
        end
      else
        # add errors to output
        File.open(@errfile, 'a') do |f|
          f.write err
        end
      end
    end
  end
end
