########################################################################
# File::    service.rb
# (C)::     Loyalty New Zealand 2014
#
# Purpose:: Define a class that service authors subclass and use to
#           declare the component interfaces within the service via a
#           very small DSL.
#
#           This class is passed to Rack and treated like an endpoint
#           Rack application, though the service middleware in practice
#           does not pass on calls using the Rack interface; it uses the
#           custom calls exposed by Hoodoo::Services::Implementation.
#           Rack's involvement between the two is really limited to just
#           passing an instance of the service application subclass to
#           the middleware so it knows who to "talk to".
# ----------------------------------------------------------------------
#           23-Sep-2014 (ADH): Created.
########################################################################

module Hoodoo; module Services

  # Hoodoo::Services::Service is subclassed by people writing service
  # implementations; the subclasses are the entrypoint for platform services.
  #
  # It's really just a container of one or more interface classes, which are
  # all Hoodoo::Services::Interface subclasses. The Rack middleware in
  # Hoodoo::Services::Middleware uses the Hoodoo::Services::Service to find
  # out what interfaces it implements. Those interface classes nominate a Ruby
  # class of the author's choice in which they've written the implementation
  # for that interface. Interfaces also declare themselves to be available at
  # a particular URL endpoint (as a path fragment); this is used by the
  # middleware to route inbound requests to the correct implementation class.
  #
  # Suppose we defined a PurchaseInterface and RefundInterface which we wanted
  # both to be available as a Shopping Service:
  #
  #     class PurchaseImplementation < Hoodoo::Services::Implementation
  #       # ...
  #     end
  #
  #     class PurchaseInterface < Hoodoo::Services::Interface
  #       interface :Purchase do
  #         endpoint :purchases, PurchaseImplementation
  #         # ...
  #       end
  #     end
  #
  #     class RefundImplementation < Hoodoo::Services::Implementation
  #       # ...
  #     end
  #
  #     class RefundInterface < Hoodoo::Services::Interface
  #       interface :Refund do
  #         endpoint :refunds, RefundImplementation
  #         # ...
  #       end
  #     end
  #
  # ...then the *entire* Service subclass for the Shopping Service
  # could be as small as this:
  #
  #     class ShoppingService < Hoodoo::Services::Service
  #       comprised_of PurchaseInterface,
  #                    RefundInterface
  #     end
  #
  # Names of subclasses in the above examples are chosen for clarity and the
  # naming approach indicated is recommended, but it's not mandatory. Choose
  # choose whatever you feel best fits your code and style.
  #
  # Conceptually, one might just have a single interface per application for
  # very small services, but you may want to logically group more interfaces in
  # one service for code clarity/locality. More realistically, efficiency may
  # dictate that certain interfaces have such heavy reliance and relationships
  # between database contents that sharing the data models between those
  # interface classes makes sense; you would group them under the same service
  # application, sacrificing full decoupling. As a service author, the choice
  # is yours.
  #
  class Service

    # Return an array of the classes that make up the interfaces for this
    # service. Each is a Hoodoo::Services::Interface subclass that was
    # registered by the subclass through a call to #comprised_of.
    #
    def self.component_interfaces
      @component_interfaces
    end

    # Instance method which calls through to ::component_interfaces and returns
    # its result.
    #
    def component_interfaces
      self.class.component_interfaces
    end

    # Since service implementations are not pure Rack apps but really service
    # middleware clients, they shouldn't ever have "call" invoked directly.
    # This method is not intended to be overridden and just complains if Rack
    # ends up calling here directly by accident.
    #
    # +env+:: Rack environment (ignored).
    #
    def call( env )
      raise "Hoodoo::Services::Service subclasses should only be called through the middleware - add 'use Hoodoo::Services::Middleware' to (e.g.) config.ru"
    end

  protected

    # Called by subclasses listing one or more Hoodoo::Services::Interface
    # subclasses that make up the service implementation as a whole.
    #
    # Example:
    #
    #     class ShoppingService < Hoodoo::Services::Service
    #       comprised_of PurchaseInterface,
    #                    RefundInterface
    #     end
    #
    # See this class's general Hoodoo::Services::Service documentation for
    # more details.
    #
    def self.comprised_of( *classes )

      # http://www.ruby-doc.org/core-2.2.3/Module.html#method-i-3C
      #
      classes.each do | klass |
        unless klass < Hoodoo::Services::Interface
          raise "Hoodoo::Services::Service::comprised_of expects Hoodoo::Services::Interface subclasses only - got '#{ klass }'"
        end
      end

      # Add the classes from this call to any given in a previous call.

      @component_interfaces ||= []
      @component_interfaces += classes
      @component_interfaces.uniq!
    end
  end

end; end
