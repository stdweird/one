#!/usr/bin/env ruby

# -------------------------------------------------------------------------- #
# Copyright 2002-2015, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

ONE_LOCATION=ENV["ONE_LOCATION"]

if !ONE_LOCATION
    RUBY_LIB_LOCATION="/usr/lib/one/ruby"
    ETC_LOCATION="/etc/one/"
else
    RUBY_LIB_LOCATION=ONE_LOCATION+"/lib/ruby"
    ETC_LOCATION=ONE_LOCATION+"/etc/"
end

$: << RUBY_LIB_LOCATION


require 'scripts_common'
require 'OpenNebulaDriver'
require 'getoptlong'
require 'shellwords'

# This is a generic AuthZ/AuthN driver able to manage multiple authentication
# protocols (simultaneosly). It also supports the definition of custom
# authorization methods
class AuthDriver < OpenNebulaDriver

    # Auth Driver Protocol constants
    ACTION = {
        :authN => "AUTHENTICATE",
        :authZ => "AUTHORIZE"
    }


    # Initialize an AuthDriver
    #
    # @param [String] the authorization method to be used, nil to use the
    #        built-in ACL engine
    # @param [Array] authentication modules enabled, nil will use any
    #        any method existing in remotes directory
    def initialize(authZ, authN, nthreads)
        super(
            "auth",
            :concurrency   => nthreads,
            :threaded      => nthreads > 0,
            :local_actions => {ACTION[:authN] => nil, ACTION[:authZ] => nil}
        )

        register_action(ACTION[:authN].to_sym, method("authN"))
        register_action(ACTION[:authZ].to_sym, method("authZ"))

        if authZ != nil
            @authZ_cmd = File.join(@local_scripts_path, authZ)
            @authZ_cmd = File.join(@authZ_cmd, ACTION[:authZ].downcase)
        else
            @authZ_cmd = nil
        end

        if authN == nil
            # get the directories from remotes dir that have an authenticate
            # script
            @authN_protocols=Dir[@local_scripts_path+"/*/authenticate"].map do |d|
                d.split('/')[-2]
            end
        else
            if authN.class==String
                @authN_protocols=[authN]
            else
                @authN_protocols=authN
            end
        end
    end


    # Works the same as log_method but changes the password by '****'.
    # The last word is the password for authentication.
    def log_method_no_password(num, secret)
        lambda {|message|
            m=message.gsub(/ #{Regexp.escape(secret)}$/, ' ****')
            log(num, m)
        }
    end

    # Authenticate a user based in a string of the form user:secret when using the
    # driver secret is protocol:token
    # @param [String] the id for this request, used by OpenNebula core
    #        to identify the request
    # @param [String] id of the user, "-1" if not in defined in OpenNebula
    # @param [String] driver to be used
    # @param [Strgin] user filed of the auth string
    # @param [String] password of the user registered in OpenNebula "-" if none
    # @param [String] secret filed of the auth string
    def authN(request_id, user_id, driver, user, password, secret)

        #OpenNebula.log_debug("authN: #{request_id} #{user_id} #{driver} #{password} #{secret}")

        unless @authN_protocols.include?(driver)
            return send_message(
                ACTION[:authN],
                RESULT[:failure],
                request_id,
                "Authentication driver '#{driver}' not available")
        end

        #build path for the auth action
        #/var/lib/one/remotes/auth/<driver>/authenticate
        authN_path = File.join(@local_scripts_path, driver)

        command = File.join(authN_path, ACTION[:authN].downcase)
        command << ' ' << ([user, password, secret].map do |p|
            Shellwords.escape(p)
        end.join(' '))

        rc = LocalCommand.run(command,
            log_method_no_password(request_id, Shellwords.escape(secret)))

        result , info = get_info_from_execution(rc)

        send_message(ACTION[:authN], result, request_id, info)
    end

    # Authenticate a user based in a string of the form user:secret when using the
    # driver secret is protocol:token
    # @param [String] the id for this request, used by OpenNebula core
    #        to identify the request
    # @param [String] id of the user, "-1" if not in defined in OpenNebula
    # @param [Array] of auth strings, last element is the ACL evaluation of
    #        the overall request (0 = denied, 1 = granted). Each request is in
    #        the form:
    #        OBJECT:<TEMPLATE_64|OBJECT_ID>:OPERATION:OWNER:ACL_EVAL
    def authZ(request_id, user_id, *requests)

        requests.flatten!

        #OpenNebula.log_debug("authZ: #{request_id} #{user_id} #{requests}")

        if @authZ_cmd == nil
            if requests[-1] == "1"
                result = RESULT[:success]
            else
                result = RESULT[:failure]
            end

            send_message(ACTION[:authZ], result, request_id, "-")
        else
            command = @authZ_cmd.clone
            command << ' ' << user_id << ' ' << requests.join(' ')

            rc = LocalCommand.run(command, log_method(request_id))

            result , info = get_info_from_execution(rc)

            send_message(ACTION[:authZ], result, request_id, info)
        end
    end
end

# Auth Driver Main program
opts = GetoptLong.new(
    [ '--threads',    '-t', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--authz',      '-z', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--authn',      '-n', GetoptLong::REQUIRED_ARGUMENT ]
)

threads = 15
authz   = nil
authn   = nil

begin
    opts.each do |opt, arg|
        case opt
            when '--threads'
                threads = arg.to_i
            when '--authz'
                authz   = arg
            when '--authn'
                authn   = arg.split(',').map {|a| a.strip }
        end
    end
rescue Exception => e
    exit(-1)
end

auth_driver = AuthDriver.new(authz, authn, threads)

auth_driver.start_driver
