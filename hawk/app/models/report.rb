# Copyright (c) 2009-2015 Tim Serong <tserong@suse.com>
# See COPYING for license.

require 'fileutils'

class Report
  attr_accessor :id
  attr_accessor :name
  attr_accessor :path
  attr_accessor :meta
  attr_accessor :from_time
  attr_accessor :to_time
  attr_accessor :gen_output
  attr_accessor :gen_error
  attr_accessor :transitions
  attr_accessor :node_events
  attr_accessor :resource_events
  attr_accessor :hb_report

  def initialize(attributes)
    attributes.each { |key, value| send("#{key}=".to_sym, value) }
    @hb_report = HbReport.new @name
  end

  def delete
    hb_report.delete
  end

  def report_path
    self.class.report_path
  end

  # Returns [filename, mimetype]
  def archive
    hb_report.archive
  end

  def info(transition)
    out, _err = hb_report.info transition
    out
  end

  def cib(transition)
    hb_report.cib transition
  end

  def tags(transition)
    hb_report.tags transition
  end

  def logs(transition)
    hb_report.logs transition
  end

  def graph(transition, format = :svg)
    hb_report.graph transition, format
  end

  def diff(left, right, format = :html)
    hb_report.diff left, right, format
  end

  class << self
    def find(id)
      rl = report_list
      meta = rl[id]
      Report.new meta if meta
    end

    def all
      report_list.values.map do |meta|
        Report.new meta
      end.sort_by(&:name)
    end

    def report_list
      {}.tap do |ret|
        Pathname.glob(report_path.join('*.meta.json')).map do |meta|
          begin
            data = JSON.parse(IO.read(meta))
            ret[data["id"]] = data
          rescue JSON::ParserError => e
            Rails.logger.debug "#{e}"
          end
        end
      end
    end

    def report_path
      @report_path ||= Rails.root.join("tmp", "reports")
      @report_path.mkpath unless @report_path.directory?
      @report_path
    end
  end

  class Upload < Tableless
    attribute :upload, ActionDispatch::Http::UploadedFile

    validate do |record|
      unless ["application/x-bzip", "application/x-xz", "application/x-gz"].include? record.upload.content_type
        errors.add(:upload, _("must have correct MIME type"))
      end

      unless record.upload.original_filename =~ /\.tar\.(bz2|gz|xz)\z/
        errors.add(:upload, _("must have correct file extension"))
      end
    end

    def new_record?
      false
    end

    def persisted?
      true
    end

    protected

    def persist!
      path = Rails.root.join("tmp", "reports")
      path.mkpath unless path.directory?
      path = path.join(@upload.original_filename)
      FileUtils.rm path if path.file?
      FileUtils.cp @upload.tempfile.to_path, path
      Rails.logger.debug "Uploaded to #{path}"
      # TODO
      true
    end
  end
end
