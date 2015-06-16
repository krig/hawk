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

class Tableless
  class ValidationError < RuntimeError
  end

  extend ActiveModel::Naming

  include Virtus.model

  include ActiveModel::Conversion
  include ActiveModel::Validations
  include FastGettext::Translation

  attr_accessor :new_record

  def initialize(attrs = nil)
    self.attributes = attrs unless attrs.nil?
    self.new_record = true
    super
  end

  def save
    if valid? and persist!
      true
    else
      false
    end
  end

  def persisted?
    if self.new_record
      false
    else
      true
    end
  end

  def new_record?
    if self.new_record
      true
    else
      false
    end
  end

  def update_attributes(attrs = nil)
    self.attributes = attrs unless attrs.nil?
    self.save
  end

  def validate!
    raise ValidationError, errors unless valid?
  end

  protected

  def create
  end

  def update
  end

  def persist!
    if new_record?
      create
    else
      update
    end
  end
end
