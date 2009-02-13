require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

include Castronaut::Models

describe Castronaut::Models::TicketGrantingTicket do

  it "has no proxies" do
    TicketGrantingTicket.new.proxies.should be_nil
  end

  it "has a ticket prefix of TGC" do
    TicketGrantingTicket.new.ticket_prefix.should == 'TGC'
  end

  it "is aware of it's expiry time" do
    Castronaut.stub!(:config).and_return(mock('config', :tgt_expiry_time => 60)) 
    TicketGrantingTicket.expiry_time.should == 60
  end

  describe "validating ticket granting ticket" do

    describe "when given no ticket" do

      it "has a message explaining you must give a ticket" do
        TicketGrantingTicket.validate_cookie(nil).message.should == 'No ticket granting ticket given'
      end
      
      it "is invalid" do
        TicketGrantingTicket.validate_cookie(nil).should be_invalid
      end
      
    end

    describe "when given a ticket" do

      it "attempts to find the ticket granting ticket in the database" do
        TicketGrantingTicket.should_receive(:find_by_ticket).and_return(nil)
        TicketGrantingTicket.validate_cookie('abc')
      end

      describe "when it finds a ticket granting ticket" do

        before do
          @ticket_granting_ticket = TicketGrantingTicket.new
          @ticket_granting_ticket.stub!(:username).and_return('bob_smith')
          @ticket_granting_ticket.stub!(:expired?).and_return(false)
          TicketGrantingTicket.stub!(:find_by_ticket).and_return(@ticket_granting_ticket)
        end

        it "returns an error message if the ticket granting ticket is expired" do
          @ticket_granting_ticket.stub!(:expired?).and_return(true)
          TicketGrantingTicket.validate_cookie('abc').message.should == "Your session has expired. Please log in again."
        end

      end

    end

    describe "in all other cases" do

      it "returns a TicketResult with no error message" do
        TicketGrantingTicket.stub!(:find_by_ticket).and_return(nil)
        TicketGrantingTicket.validate_cookie('abc').message.should be_nil
      end

    end

  end

  describe "generating for a username and client host" do

    it "delegates to :create!" do
      TicketGrantingTicket.should_receive(:create!).with(:username => 'username', :client_hostname => 'client_host')
      TicketGrantingTicket.generate_for('username', 'client_host')
    end

  end
  
  describe "general accessors" do
    
    it "returns the value of the ticket column for to_cookie" do
      tgt = TicketGrantingTicket.new
      tgt.stub!(:ticket).and_return("ticket")
      tgt.to_cookie.should == "ticket"
    end
    
    it "never expires by default" do
      tgt = TicketGrantingTicket.new
      tgt.created_at = Time.now - 100000
      TicketGrantingTicket.stub!(:expiry_time).and_return(0)
      tgt.expired?.should == false
    end

    it "expires according to the config setting" do
      TicketGrantingTicket.stub!(:expiry_time).and_return(60)
      tgt = TicketGrantingTicket.new
      tgt.created_at = Time.now - 61
      tgt.expired?.should == true
      tgt.created_at = Time.now - 58
      tgt.expired?.should == false
    end
    
  end

end
