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

class Node < Record
  class CommandError < StandardError
  end

  attribute :id, String
  attribute :name, String
  attribute :attrs, Hash
  attribute :utilization, Hash
  attribute :state, String
  attribute :online, Boolean
  attribute :standby, Boolean
  attribute :ready, Boolean
  attribute :maintenance, Boolean
  attribute :fence, Boolean

  validates :id,
    presence: { message: _('Node ID is required') },
    format: { with: /\A[0-9]+\z/, message: _('Invalid Node ID') }

  validates :name,
    presence: { message: _('Name is required') },
    format: { with: /\A[a-zA-Z0-9_-]+\z/, message: _('Invalid name') }

  def state
    case
    when fence
      :fence
    when maintenance || standby
      :offline
    when online || ready
      :online
    else
      :unknown
    end
  end

  def online!
    result = Invoker.instance.run(
      "crm_attribute", "-N", name, "-n", "standby", "-v", "off", "-l", "forever"
    )

    if result == true
      true
    else
      raise CommandError.new result.last
    end
  end

  def online
    if attrs['standby'] and attrs['standby'] == 'off'
      true
    else
      false
    end
  end

  def standby!
    result = Invoker.instance.run(
      "crm_attribute", "-N", name, "-n", "standby", "-v", "on", "-l", "forever"
    )

    if result == true
      true
    else
      raise CommandError.new result.last
    end
  end

  def standby
    if attrs['standby'] and attrs['standby'] == 'on'
      true
    else
      false
    end
  end

  def ready!
    result = Invoker.instance.run(
      "crm_attribute", "-N", name, "-n", "maintenance", "-v", "off", "-l", "forever"
    )

    if result == true
      true
    else
      raise CommandError.new result.last
    end
  end

  def ready
    if attrs['maintenance'] and attrs['maintenance'] == 'off'
      true
    else
      false
    end
  end

  def maintenance!
    result = Invoker.instance.run(
      "crm_attribute", "-N", name, "-n", "maintenance", "-v", "on", "-l", "forever"
    )

    if result == true
      true
    else
      raise CommandError.new result.last
    end
  end

  def maintenance
    if attrs['maintenance'] and attrs['maintenance'] == 'on'
      true
    else
      false
    end
  end

  def fence!
    result = Invoker.instance.run(
      "crm_attribute", "-t", "status", "-U", name, "-n", "terminate", "-v", "true"
    )

    if result == true
      true
    else
      raise CommandError.new result.last
    end
  end

  def fence
    # TODO(must): How to detect fence for nodes?
    false
  end

  def to_param
    name
  end

  protected

  class << self
    def instantiate(xml)
      record = allocate
      record.name = xml.attributes['uname'] || ''

      record.attrs = if xml.elements['instance_attributes']
        vals = xml.elements['instance_attributes'].elements.collect do |e|
          [
            e.attributes['name'],
            e.attributes['value']
          ]
        end

        Hash[vals.sort]
      else
        {}
      end

      record.utilization = if xml.elements['utilization']
        vals = xml.elements['utilization'].elements.collect do |e|
          [
            e.attributes['name'],
            e.attributes['value']
          ]
        end

        Hash[vals.sort]
      else
        {}
      end

      if record.utilization.any?
        Util.safe_x('/usr/sbin/crm_simulate', '-LU').split('\n').each do |line|
          m = line.match(/^Remaining:\s+([^\s]+)\s+capacity:\s+(.*)$/)

          next unless m
          next unless m[1] == record.uname

          m[2].split(' ').each do |u|
            name, value = u.split('=', 2)

            if record.utilization.has_key? name
              record.utilization[name][:remaining] = value.to_i
            end
          end
        end
      end

      record
    end

    def cib_type
      :node
    end

    def ordered
      all.sort do |a, b|
        a.name.natcmp(b.name, true)
      end
    end

    # Since pacemaker started using corosync node IDs as the node ID attribute,
    # Record#find will fail when looking for nodes by their human-readable
    # name, so have to override here
    def find(id)
      begin
        super(id)
      rescue CibObject::RecordNotFound
        # Can't find by id attribute, try by uname attribute
        super(name, 'uname')
      end
    end
  end
end
