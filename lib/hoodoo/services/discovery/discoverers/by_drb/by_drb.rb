########################################################################
# File::    by_drb.rb
# (C)::     Loyalty New Zealand 2015
#
# Purpose:: Discover resource endpoint locations via a DRb registry. For
#           HTTP-based endpoints.
# ----------------------------------------------------------------------
#           03-Mar-2015 (ADH): Created.
########################################################################

require 'drb/drb'

module Hoodoo
  module Services
    class Discovery # Just used as a namespace here

      # Discover resource endpoint locations via a DRb registry. For
      # HTTP-based endpoints.
      #
      class ByDRb < Hoodoo::Services::Discovery

        public

          # Intended for testing only - flushes the records held in the
          # DRb service.
          #
          def flush_services_for_test
            drb_service().flush()
          end

        protected

          # Configure an instance. Call via
          # Hoodoo::Services::Discovery::Base#new. Parameters:
          #
          # +options+:: Options hash as described below.
          #
          # Options are:
          #
          # +drb_port+:: Optional port on which to launch the DRb service.
          #              If omitted, environment variable
          #              +HOODOO_DISCOVERY_BY_DRB_PORT_OVERRIDE+ will be
          #              consulted. If unset, port 8787 is used.
          #
          # +drb_uri+::  Optional URI String at which to find an existing DRB
          #              service. It must alreayd be running. If omitted, the
          #              +drb_port+ option's behaviour applies. If present,
          #              the +drb_port+ option is ignored.
          #
          def configure_with( options )
            @drb_port = options[ :drb_port ]
            @drb_uri  = options[ :drb_uri  ]
          end

          # Announce the location of an instance through the DRb service
          # (which may be started up if necessary).
          #
          # Returns a Hoodoo::Services::Discovery::ForHTTP instance.
          #
          # Call via Hoodoo::Services::Discovery::Base#announce.
          #
          # +resource+:: Passed to #discover_remote.
          # +version+::  Passed to #discover_remote.
          # +options+::  Options hash as described below.
          #
          # Options keys are:
          #
          # +host+:: Host name as a string for location of service endpoint,
          #          over HTTP (usually, local development is assumed).
          #
          # +port+:: Port number of service endpoint.
          #
          # +path+:: Path on the above host and port of service endpoint.
          #
          # If any are missing or +nil+, remote announcement is aborted and
          # the return value is correspondingly +nil+.
          #
          def announce_remote( resource, version, options = {} )

            host = options[ :host ]
            port = options[ :port ]
            path = options[ :path ]

            endpoint_uri_string = unless host.nil? || port.nil? || path.nil?
              "http://#{ host }:#{ port }#{ path }"
            end

            # Announce our local services only if we have an endpoint URI. In a
            # 'guard' based environment, first-run determines host and port but
            # subsequent runs do not - yet it stays the same, so it works out
            # OK there.
            #
            unless endpoint_uri_string.nil? || discover_remote( resource, version )
              drb_service().add( resource, version, endpoint_uri_string )
            end

            return result_for( resource, version, endpoint_uri_string )
          end

          # Discover an endpoint someone previously registered via
          # #announce_remote.
          #
          # Returns a Hoodoo::Services::Discovery::ForHTTP instance if
          # the endpoint is found, else +nil+.
          #
          # +resource+:: Resource name as a String.
          # +version+::  Endpoint version as an Integer.
          #
          def discover_remote( resource, version )
            endpoint_uri_string = drb_service().find( resource, version )
            return result_for( resource, version, endpoint_uri_string )
          end

        private

          # Construct a Hoodoo::Services::Discovery::ForHTTP instance for
          # the given parameters.
          #
          # +resource+::            Resource name as a String.
          # +version+::             Endpoint version as an Integer.
          # +endpoint_uri_string+:: Endpoint location as a URI expressed
          #                         as a String; may be +nil+.
          #
          # Returns the new instance, or +nil+ if the endpoint URI String
          # was itself +nil+.
          #
          def result_for( resource, version, endpoint_uri_string )
            if endpoint_uri_string.nil?
              return nil
            else
              return Hoodoo::Services::Discovery::ForHTTP.new(
                resource:     resource,
                version:      version,
                endpoint_uri: URI.parse( endpoint_uri_string )
              )
            end
          end

          # Start the DRb service on the port configured for this instance
          # via its constructor and return a DRbObject instance to use for
          # talking to it.
          #
          # Raises an exception if the DRb service cannot be started.
          #
          def drb_service

            # Attempt to contact the DRb server daemon. If it can't be
            # contacted, try to start it first, then connect.

            if @drb_uri.nil? || @drb_uri.empty?
              drb_uri = Hoodoo::Services::Discovery::ByDRb::DRbServer.uri( @drb_port )
              start_on_localhost_if_not_already_running = true
            else
              drb_uri = @drb_uri
              start_on_localhost_if_not_already_running = false
            end

            begin
              drb_service = DRbObject.new_with_uri( drb_uri )
              drb_service.ping()

            rescue DRb::DRbConnError
              if start_on_localhost_if_not_already_running
                script_path = File.join( File.dirname( __FILE__ ), 'drb_server_start.rb' )
                command     = "#{ defined?( Bundler ) ? 'bundle exec ' : '' }ruby '#{ script_path }'"
                command    << " --port #{ @drb_port }" unless @drb_port.nil? || @drb_port.empty?

                Process.detach( spawn( command ) )

                begin
                  Timeout::timeout( 5 ) do
                    loop do
                      begin
                        drb_service = DRbObject.new_with_uri( drb_uri )
                        drb_service.ping()
                        break
                      rescue DRb::DRbConnError
                        sleep 0.1
                      end
                    end
                  end

                rescue Timeout::Error
                  raise "Hoodoo::Services::Discovery::ByDRb timed out while waiting for DRb service registry to start on local port #{ @drb_port }"

                end

              else
                raise "Hoodoo::Services::Discovery::ByDRb could not contact a DRb service registry at #{ @drb_uri }"

              end
            end

            return drb_service
          end

      end
    end
  end
end
