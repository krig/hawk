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

# Note that Colocation and Order use of the resources array is the
# inverse of each other, always, regardless of inconsistencies in
# the underlying configuraton.  e.g. (simplified):
#
#   order.resources = [ 'A', 'B', 'C' ];
#   colocation.resources = [ 'C', 'B', 'A' ];

class Colocation < Constraint
  attribute :id, String
  attribute :score, String
  attribute :resources, Array[Hash]

  validates :id,
    presence: { message: _("Constraint ID is required") },
    format: { with: /\A[a-zA-Z0-9_-]+\z/, message: _("Invalid Constraint ID") }

  validates :score,
    presence: { message: _("Score is required") }

  validate do |record|
    record.score.strip!

    unless [
      "mandatory",
      "advisory",
      "inf",
      "-inf",
      "infinity",
      "-infinity"
    ].include? record.score.downcase
      unless record.score.match(/^-?[0-9]+$/)
        errors.add :score, _('Invalid score value')
      end
    end

    if record.resources.length < 2
      errors.add :base, _("Constraint must consist of at least two separate resources")
    end
  end

  def resources
    @resources ||= []
  end

  def resources=(value)
    @resources = value
  end

  class << self
    def all
      super.select do |record|
        record.is_a? self
      end
    end
  end

  protected

  def shell_syntax



    raise "Seems to be valid!".inspect



    [].tap do |cmd|
      cmd.push "colocation #{id} #{score}:"

      #
      # crm syntax matches nasty inconsistency in CIB, i.e. to get:
      #
      #   d6 -> d5 -> ( d4 d3 ) -> d2 -> d1 -> d0
      #
      # you use:
      #
      #   colocation <id> <score>: d5 d6 ( d3 d4 ) d0 d1 d2
      #
      # except when using simple constrains, i.e. to get:
      #
      #   d1 -> d0
      #
      # you use:
      #
      #   colocation <id> <score>: d1 d0
      #
      # To further confuse matters, duplicate roles in complex chains
      # are collapsed to sets, so for:
      #
      #   d2:Master -> d1:Started -> d0:Started
      #
      # you use:
      #
      #   colocation <id> <score>: d2:Master d0:Started d1:Started
      #
      # To deal with this, we need to collapse all the sets first
      # then iterate through them (unlike the Order model, where
      # this is unnecessary)
      #




      # Have to clone out of @resources, else we've just got references
      # to elements of @resources inside collapsed, which causes @resources
      # to be modified, which we *really* don't want.

      # collapsed = [ resources.first.clone ]
      # resources.last(resources.length - 1).each do |set|
      #   if collapsed.last[:sequential] == set[:sequential] && collapsed.last[:role] == set[:role]
      #     collapsed.last[:resources] += set[:resources]
      #   else
      #     collapsed << set.clone
      #   end
      # end

      # if collapsed.length == 1 && collapsed[0][:resources].length == 2
      #   # Simple constraint (it's already in reverse order so
      #   # don't flip around the other way like we do below)
      #   collapsed[0][:resources].each do |r|
      #     cmd += " #{r[:id]}"
      #     cmd += ":#{set[:role]}" if collapsed[0][:role]
      #   end
      # else
      #   collapsed.each do |set|
      #     cmd += " ( " unless set[:sequential]
      #     set[:resources].reverse.each do |r|
      #       cmd += " #{r[:id]}"
      #       cmd += ":#{set[:role]}" if set[:role]
      #     end
      #     cmd += " )" unless set[:sequential]
      #   end
      # end





      # resources.each do |key, resource|
      #   if resource.role
      #     cmd.push [
      #       resource.id,
      #       resource.role
      #     ].join(":")
      #   else
      #     cmd.push resource.id
      #   end
      # end






    end.join(" ")
  end

  class << self
    def instantiate(xml)
      record = allocate
      record.score = xml.attributes["score"] || nil

      record.resources = [].tap do |resources|
        if xml.attributes["rsc"]
          resources.push(
            sequential: true,
            role: xml.attributes["rsc-role"] || nil,
            resources: [
              xml.attributes["rsc"]
            ]
          )

          resources.push(
            sequential: true,
            role: xml.attributes["with-rsc-role"] || nil,
            resources: [
              xml.attributes["with-rsc"]
            ]
          )
        else
          xml.elements.each do |resource|
            set = {
              sequential: Util.unstring(resource.attributes["sequential"], true),
              role: resource.attributes['role'] || nil,
              resources: []
            }

            resource.elements.each do |el|
              set[:resources].unshift(
                el.attributes["id"]
              )
            end

            resources.push set
          end
        end
      end

      record
    end

    def cib_type_write
      :rsc_colocation
    end
  end
end
