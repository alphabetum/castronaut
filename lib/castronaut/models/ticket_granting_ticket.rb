module Castronaut
  module Models

    class TicketGrantingTicket < ActiveRecord::Base
      include Castronaut::Models::Consumeable
      include Castronaut::Models::Dispenser

      has_many :service_tickets, :dependent => :destroy

      before_validation :dispense_ticket, :if => :new_record?
      validates_presence_of :ticket, :username

      def self.validate_cookie(ticket_cookie)
        Castronaut.logger.debug("#{self} - Validating ticket for #{ticket_cookie}")

        return Castronaut::TicketResult.new(nil, "No ticket granting ticket given", 'warn') if ticket_cookie.nil?

        ticket_granting_ticket = find_by_ticket(ticket_cookie)

        if ticket_granting_ticket
          Castronaut.logger.debug("#{self} -[#{ticket_cookie}] for [#{ticket_granting_ticket.username}] successfully validated.")
          if ticket_granting_ticket.expired?
            delete ticket_granting_ticket
            return Castronaut::TicketResult.new(ticket_granting_ticket, "Your session has expired. Please log in again.", 'warn') if ticket_granting_ticket.expired?
          end
        else
          Castronaut.logger.debug("#{self} - [#{ticket_cookie}] was not found in the database.")
          return Castronaut::TicketResult.new(ticket_granting_ticket, "Your session is no longer valid.  Please log in again.", 'warn')
        end

        Castronaut::TicketResult.new(ticket_granting_ticket)
      end

      def self.generate_for(username, client_host)
        create! :username => username, :client_hostname => client_host
      end

      def self.expiry_time
        Castronaut.config.tgt_expiry_time
      end
      
      def ticket_prefix
        "TGC"
      end
      
      def proxies
      end

      def to_cookie
        ticket
      end

      def expired?
        return false if self.class.expiry_time == 0
        Time.now - created_at > self.class.expiry_time 
      end
 
    end

  end
end
