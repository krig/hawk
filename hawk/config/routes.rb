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

Rails.application.routes.draw do
  root :to => 'pages#index'

  resources :cib, only: [:show] do
    member do
      get :mini, action: "show", mini: true
    end

    resources :nodes do
      member do
        get :online
        get :standby
        get :maintenance
        get :ready
        get :fence
        get :events
      end
    end

    resources :resources do
      member do
        get :start
        get :stop
        get :unmigrate
        get :promote
        get :demote
        get :cleanup
        get :manage
        get :unmanage
        get :migrate
        get :delete
        get :events
      end

      collection do
        get :types
      end
    end

    resources :primitives do
      member do
        get :intervals
      end

      collection do
        get :types
        get :metadata
      end
    end

    resources :constraints do
      member do
        get :events
      end

      collection do
        get :types
      end
    end

    resources :tickets do
      member do
        get :grant
        get :revoke
      end
    end

    resources :clones
    resources :masters
    resources :wizards
    resources :locations
    resources :colocations
    resources :orders
    resources :groups
    resources :templates
    resources :roles
    resources :users

    resource :profile, only: [:edit, :update]
    resource :crm_config, only: [:edit, :update]
    resource :dashboard, only: [:show]

    resource :checks, only: [] do
      collection do
        get :status
      end
    end
  end

  scope :reports do
    resources :heartbeats do
      collection do
        get :status
      end
    end

    #resources :explorer do
    #  member do
    #    get :diff
    #  end
    #end

    resources :graphs do
      member do
        get :gen
      end
    end
  end


  get 'explorer' => 'explorer#index', :as => :explorer


  match 'main/status' => 'main#status', :as => :status, via: [:get, :post]
  match 'main/sim_reset' => 'main#sim_reset', :as => :sim_reset, via: [:get, :post]
  match 'main/sim_run' => 'main#sim_run', :as => :sim_run, via: [:get, :post]
  match 'main/sim_get' => 'main#sim_get', :as => :sim_get, via: [:get, :post]





  get 'monitor' => 'pages#monitor', :as => :monitor
  get 'help' => 'pages#help', :as => :help

  get 'logout' => 'sessions#destroy', :as => :logout
  get 'login' => 'sessions#new', :as => :login

  post 'login' => 'sessions#create', :as => :signin
end
