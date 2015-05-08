#======================================================================
#                        HA Web Konsole (Hawk)
# --------------------------------------------------------------------
#            A web-based GUI for managing and monitoring the
#          Pacemaker High-Availability cluster resource manager
#
# Copyright (c) 2009-2015 SUSE LLC, All Rights Reserved.
#
# Author: Tim Serong <tserong@suse.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it would be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# Further, this software is distributed without any warranty that it is
# free of the rightful claim of any third person regarding infringement
# or the like.  Any license provided herein, whether implied or
# otherwise, applies only to this software file.  Patent licenses, if
# any, provided herein do not apply to combinations of this program with
# other software, or any other product whatsoever.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston MA 02111-1307, USA.
#
#======================================================================

class CrmConfig < Tableless
  RSC_DEFAULTS = {
    "allow-migrate" => {
      type: "boolean",
      default: "false"
    },
    "is-managed" => {
      type: "boolean",
      default: "true"
    },
    "maintenance" => {
      type: "boolean",
      default: "false"
    },
    "interval-origin" => {
      type: "integer",
      default: "0"
    },
    "migration-threshold" => {
      type: "integer",
      default: "0"
    },
    "priority" => {
      type: "integer",
      default: "0"
    },
    "multiple-active" => {
      type: "enum",
      default: "stop_start",
      values: ["block", "stop_only", "stop_start"]
    },
    "failure-timeout" => {
      type: "integer",
      default: "0"
    },
    "resource-stickiness" => {
      type: "integer",
      default: "0"
    },
    "target-role" => {
      type: "enum",
      default: "Started",
      values: ["Started", "Stopped", "Master"]
    },
    "restart-type" => {
      type: "enum",
      default: "ignore",
      values: ["ignore", "restart"]
    },
    "description" => {
      type: "string",
      default: ""
    }
  }.freeze

  OP_DEFAULTS = {
    "interval" => {
      type: "string",
      default: 0
    },
    "timeout" => {
      type: "string",
      default: "20"
    },
    "requires" => {
      type: "enum",
      default: "fencing",
      values: ["nothing", "quorum", "fencing"]
    },
    "enabled" => {
      type: "boolean",
      default: "true"
    },
    "role" => {
      type: "enum",
      default: "",
      values: ["Stopped", "Started", "Slave", "Master"]
    },
    "on-fail" => {
      type: "enum",
      default: "stop",
      values: ["ignore", "block", "stop", "restart", "standby", "fence"]
    },
    "start-delay" => {
      type: "string",
      default: "0"
    },
    "interval-origin" => {
      type: "string",
      default: "0"
    },
    "record-pending" => {
      type: "boolean",
      default: "false"
    },
    "description" => {
      type: "string",
      default: ""
    }
  }.freeze

  attribute :crm_config, Hash, default: {}
  attribute :rsc_defaults, Hash, default: {}
  attribute :op_defaults, Hash, default: {}

  def initialize(*args)
    super
    load!
  end

  def maplist(key, include_readonly = false, include_advanced = false)
    case
    when include_readonly && include_advanced
      mapping[key]
    when !include_readonly && include_advanced
      mapping[key].reject do |key, attrs|
        attrs[:readonly]
      end
    when include_readonly && !include_advanced
      mapping[key].reject do |key, attrs|
        attrs[:advanced]
      end
    else
      mapping[key].reject do |key, attrs|
        attrs[:readonly] || attrs[:advanced]
      end
    end
  end

  def mapping
    self.class.mapping
  end

  def new_record?
    false
  end

  def persisted?
    true
  end

  class << self
    def mapping
      @mapping ||= begin
        {
          rsc_defaults: RSC_DEFAULTS,
          op_defaults: OP_DEFAULTS,
          crm_config: {}.tap do |crm_config|
            [
              "pengine",
              "crmd",
              "cib"
            ].each do |cmd|
              [
                "/usr/libexec/pacemaker/#{cmd}",
                "/usr/lib64/pacemaker/#{cmd}",
                "/usr/lib/pacemaker/#{cmd}",
                "/usr/lib64/heartbeat/#{cmd}",
                "/usr/lib/heartbeat/#{cmd}"
              ].each do |path|
                next unless File.executable? path

                REXML::Document.new(%x[#{path} metadata 2>/dev/null]).tap do |xml|
                  return unless xml.root

                  xml.elements.each("//parameter") do |param|
                    name = param.attributes["name"]
                    content = param.elements["content"]
                    shortdesc = param.elements["shortdesc[@lang=\"#{I18n.locale.to_s.gsub("-", "_")}\"]|shortdesc[@lang=\"en\"]"].text || ""
                    longdesc  = param.elements["longdesc[@lang=\"#{I18n.locale.to_s.gsub("-", "_")}\"]|longdesc[@lang=\"en\"]"].text || ""

                    type = content.attributes["type"]
                    default = content.attributes["default"]

                    advanced = shortdesc.match(/advanced use only/i) || longdesc.match(/advanced use only/i)

                    crm_config[name] = {
                      type: content.attributes["type"],
                      readonly: false,
                      shortdesc: shortdesc,
                      longdesc: longdesc,
                      advanced: advanced ? true : false,
                      default: default
                    }

                    if type == "enum"
                      match = longdesc.match(/Allowed values:(.*)/i)

                      if match
                        values = match[1].split(",").map do |value|
                          value.strip
                        end.reject do |value|
                          value.empty?
                        end

                        crm_config[name][:values] = values unless values.empty?
                      end
                    end
                  end
                end

                break
              end
            end

            [
              "cluster-infrastructure",
              "dc-version",
              "expected-quorum-votes"
            ].each do |key|
              crm_config[key][:readonly] = true if crm_config[key]
            end
          end
        }.freeze
      end
    end
  end

  protected

  def xml
    @xml ||= REXML::Document.new(
      Invoker.instance.cibadmin(
        "-Ql",
        "--xpath",
        "//crm_config|//rsc_defaults|//op_defaults"
      )
    )

    unless @xml.root
      raise CibObject::CibObjectError, _("Unable to parse cibadmin output")
    end

    @xml
  end

  def crm_config_xpath
    @crm_config_xpath ||= "//crm_config/cluster_property_set[@id='cib-bootstrap-options']"
  end

  def crm_config_value
    @crm_config_value ||= xml.elements[crm_config_xpath]
  end

  def rsc_defaults_xpath
    @rsc_defaults_xpath ||= "//rsc_defaults/meta_attributes[@id='rsc-options']"
  end

  def rsc_defaults_value
    @rsc_defaults_value ||= xml.elements[rsc_defaults_xpath]
  end

  def op_defaults_xpath
    @op_defaults_xpath ||= "//op_defaults/meta_attributes[@id='op-options']"
  end

  def op_defaults_value
    @op_defaults_value ||= xml.elements[op_defaults_xpath]
  end

  def current_crm_config
    {}.tap do |current|
      crm_config_value.elements.each("nvpair") do |nv|
        next if mapping[:crm_config][nv.attributes["name"]].nil?
        current[nv.attributes["name"]] = nv.attributes["value"]
      end if crm_config_value
    end
  end

  def current_rsc_defaults
    {}.tap do |current|
      rsc_defaults_value.elements.each("nvpair") do |nv|
        next if mapping[:rsc_defaults][nv.attributes["name"]].nil?
        current[nv.attributes["name"]] = nv.attributes["value"]
      end if rsc_defaults_value
    end
  end

  def current_op_defaults
    {}.tap do |current|
      op_defaults_value.elements.each("nvpair") do |nv|
        next if mapping[:op_defaults][nv.attributes["name"]].nil?
        current[nv.attributes["name"]] = nv.attributes["value"]
      end if op_defaults_value
    end
  end

  def load!
    self.crm_config = current_crm_config
    self.rsc_defaults = current_rsc_defaults
    self.op_defaults = current_op_defaults
  end

  def persist!
    writer = {
      crm_config: {},
      rsc_defaults: {},
      op_defaults: {},
    }

    crm_config.diff(current_crm_config).each do |key, change|
      next unless maplist(:crm_config).keys.include? key
      new_value, old_value = change

      if new_value.nil? || new_value.empty?
        Invoker.instance.run("crm_attribute", "--attr-name", key, "--delete-attr")
      else
        writer[:crm_config][key] = new_value
      end
    end

    rsc_defaults.diff(current_rsc_defaults).each do |key, change|
      next unless maplist(:rsc_defaults).keys.include? key
      new_value, old_value = change

      if new_value.nil? || new_value.empty?
        Invoker.instance.run("crm_attribute", "--type", "rsc_defaults", "--attr-name", key, "--delete-attr")
      else
        writer[:rsc_defaults][key] = new_value
      end
    end

    op_defaults.diff(current_op_defaults).each do |key, change|
      next unless maplist(:op_defaults).keys.include? key
      new_value, old_value = change

      if new_value.nil? || new_value.empty?
        Invoker.instance.run("crm_attribute", "--type", "op_defaults", "--attr-name", key, "--delete-attr")
      else
        writer[:op_defaults][key] = new_value
      end
    end

    cmd = [].tap do |cmd|
      writer.each do |section, values|
        next if values.empty?

        case section
        when :crm_config
          cmd.push "property $id=\"cib-bootstrap-options\""
        when :rsc_defaults
          cmd.push "rsc_defaults $id=\"rsc-options\""
        when :op_defaults
          cmd.push "op_defaults $id=\"op-options\""
        end

        values.each do |key, value|
          cmd.push [
            key,
            value.shellescape
          ].join("=")
        end
      end
    end

    unless cmd.empty?
      Invoker.instance.crm_configure_load_update(
        cmd.join(" ")
      )
    end
  end
end
