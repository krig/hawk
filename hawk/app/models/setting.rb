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

class Setting < Tableless
  class << self
    def available_languages
      @available_languages ||= begin
        languages = YAML.load_file(
          Rails.root.join(
            'config',
            'languages.yml'
          ).to_s
        )

        result = I18n.available_locales.map do |locale|
          locale.to_s.gsub! '-', '_'
          [locale, languages[locale]]
        end.sort_by { |v| v.first.to_s }

        ActiveSupport::OrderedHash[result].symbolize_keys
      end
    end
  end

  attribute :language, String, default: ::I18n.locale

  validates :language,
    presence: {
      message: _('Language is required')
    },
    inclusion: {
      in: available_languages.keys.map(&:to_s),
      message: "Is not a valid language"
    }
end
