#
# Cookbook Name:: hawk
# Recipe:: default
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

node["hawk"]["packages"].each do |name|
  package name do
    action :install
  end
end

node["hawk"]["targets"].each do |name|
  bash "hawk_make_#{name.gsub("/", "_")}" do
    user "root"
    cwd "/vagrant"

    code <<-EOH
      make WWW_BASE=/vagrant #{name}
    EOH
  end
end
