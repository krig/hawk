# Copyright (c) 2009-2015 Tim Serong <tserong@suse.com>
# See COPYING for license.

module ReportsHelper
  def show_report_info
    [].tap do |ret|
      ret.push ["node-events", _("Node Events"), history_log_markup(@node_events)] unless @node_events.blank?
      ret.push ["resource-events", _("Resource Events"), history_log_markup(@resource_events)] unless @resource_events.blank?
      ret.push ["gen-output", _("Generation Output"), @report.gen_error] unless @report.gen_error.blank?
    end
  end
end
