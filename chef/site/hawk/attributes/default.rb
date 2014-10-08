#
# Cookbook Name:: hawk
# Attributes:: default
#
# Copyright 2014, Thomas Boerger
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

default["hawk"]["packages"] = %w(
  ruby2.1
  ruby2.1-devel

  hawk

  glib2-devel
  libxml2-devel
  pam-devel
  libpacemaker-devel
)

default["hawk"]["targets"] = %w(
  clean
  tools/hawk_chkpwd
  tools/hawk_monitor
  tools/hawk_invoke
  tools/install
)
