package ZWave::Controller;

use Moose;
use Device::SerialPort;
use Log::Log4perl qw(:easy);

use version;
our $VERSION = '0.0.1_01';

# Z-Wave With Perl proof of-concept
#
# Partial implementation of the Z-Wave "Serial API" used by most
# Z-Wave interfaces. Currently tested with the Tricklestar USB
# interface - but expected to work with most other interfaces.
#
# Currently implemented functionality:
#
#   zwave_s switch <unit> {on|off}
#
#switch a device on or off
#
#   zwave_s dim <unit> <level>
#
#       set dim level for a dimming device
#
#   zwave_s add
#
#include a device to the Z-Wave network. When requested you
#have to operate a key.
#
#

has 'port' => (isa => Str, is => 'ro', default => sub{'/dev/ttyUSB0'});
has 'device' => (isa => Object, 
		 is => 'ro', 
		 lazy => 1, 
		 default => sub{shift->init_controller});

my %addnode_status = (
    1 => "learn ready",
    2 => "node found",
    3 => "adding slave",
    4 => "adding controller",
    5 => "protocol done",
    6 => "done",
    7 => "failed",
);


sub _init_controller {
  my $serial_port = Device::SerialPort->new(shift->port, 1)
    or die("Can't open serial port $port: $^E");
  $serial_port->error_msg(1);     # use built-in error messages
  $serial_port->user_msg(0);
  $serial_port->databits(8);
  $serial_port->baudrate(115200);
  $serial_port->parity("none");
  $serial_port->stopbits(1);
  $serial_port->dtr_active(1);
  $serial_port->handshake("none");
  $serial_port->write_settings || die "Could not set up port\n";

  $serial_port; # Return port into.
}

my $cmd = shift;

my $expect_answer = 0;

if( $cmd eq "switch" ) {
   my $unit = shift;
   my $level = shift;
   $level = 0 if( $level eq "off" );
   $seq = switch( $unit, $level );
}
elsif( $cmd eq "dim" ) {
   my $unit = shift;
   my $level = shift;
   $seq = dim( $unit, $level );
}
elsif( $cmd eq "addstop" ) {
   $seq = addNodeStop();
}
elsif( $cmd eq "listen" ) {
   receive(30);
}
elsif( $cmd eq "add" ) {
   transmit( addNode() );
   receive( 60 );
   $seq = addNodeStop();
}
elsif( $cmd eq "associate" ) {
    $seq = setAssociation( shift, shift, shift );
}
elsif( $cmd eq "showassociation" ) {
    $seq = getAssociation( shift, shift );
    $expect_answer = 1;
}
else {
    print <<END ;
Usage: $0 command [options]

   switch unit {on|off}- switch a unit on or off
   dim unit level- set a dimmer to a dim level
   add- add a node

   addstop- stop adding (not needed normally)
   listen- listen for incoming packets for a while
END
    $serial_port->close();
    exit(1);
}

transmit( $seq ) if( $seq );
receive(1) if( $expect_answer );

$serial_port->close();


our $stopreceive = 0;

sub receive {
    my( $timeout ) = @_;

    my $end = time+$timeout;
    $stopreceive = 0;
    do {
      receive_once();
    } while( ($end > time) && ! $stopreceive );
}

## @fn receive_once()
# read pending bytes from the serial port, ack if they look like a packet
# 
# @return true if we got an ack, false otherwise
#
sub receive_once {
  my $gotack = 0;
  $serial_port->read_const_time(200);       # 500 milliseconds = 0.5 seconds my $input = "";   
  $input = "";
  while( 1 ) {
    my( $count, $bytes ) = $serial_port->read(1);
    $input .= $bytes;
    last unless( $count );
  }
  my @bytes = unpack( "C*", $input );
  for( my $i=0; $i<@bytes; $i++ ) {
    my $byte = $bytes[$i];
    if( $byte == 6 ) {
      DEBUG("got ack");
      $gotack++;
    }
    elsif( $byte == 1 ) {
      my $len = $bytes[$i+1];
      $i+=2;
      my @packet = ();
      for( ; $len>1; $len--, $i++ ) {
	push( @packet, $bytes[$i] );
      }
      $i++;
      handle_packet( \@packet );
      DEBUG(" ... writing ack");
      $serial_port->write(pack("C",6));
    }
  }
  return $gotack;
}


## @cmethod transmit( $data )
# transmit one packet
#
sub transmit {
  my( $seq ) = @_;

  my $retries = 4; 
  while( $retries-- && $seq ) {
    my $len = length( $seq );
    print "sending: ";
    for( my $i=2; $i<$len-1; $i++ ) {
      print sprintf( "%X ", unpack( "C", substr( $seq, $i, 1 ) ) );
    }
    print "\n";
    $serial_port->write( $seq );
    last if( receive_once() );
  }
}


sub mkreqpacket {
  my( @bytes ) = @_;

  my $len = @bytes + 1;
  unshift( @bytes, $len );
  unshift( @bytes, 0x1 );
  my $cr = 0xff;
  for( my $i=1; $i<=$len; $i++ ) {
    $cr ^= $bytes[$i];
  }
  push( @bytes, $cr );
  return @bytes;
}


sub packpack {
    my( @bytes ) = @_;

    my $seq = "";
    foreach my $byte (@bytes) {
        $seq .= pack( "C", $byte );
    }
    return $seq;
}


sub dim {
    my($unit, $level ) = @_;
    return( packpack( mkreqpacket( 0, 0x13, $unit, 3, 0x20, 1, $level, 5 ) ) );
}


sub switch {
    my( $unit, $onoff ) = @_;
    dim( $unit, $onoff ? 255 : 0 );
}


sub addNode {
    return( packpack( mkreqpacket( 0, 0x4a, 0x01 ) ) );
}

sub addNodeStop {
    return( packpack( mkreqpacket( 0, 0x4a, 0x05 ) ) );
}


sub setAssociation {
    my( $node, $group, $target ) = @_;
    return( packpack( mkreqpacket( 0, 0x13, $node, 4, 0x85, 0x01, $group, $target, 5 ) ) );
}

sub getAssociation {
    my( $node, $group ) = @_;
    return( packpack( mkreqpacket( 0, 0x13, $node, 3, 0x85, 0x02, $group, 5 ) ) );
}

#---------------------------

sub handle_packet {
  my( $pkg ) = @_;

  if( ($pkg->[1] == 0x4a) && ($pkg->[2] == 3) ) {
    # add node -- status
    $status = $pkg->[3];
    print "add node: ". $addnode_status{$status}. " ($status)";
    if( $status == 3 or $status == 4 ) {
      print "  ==> added unit: ".$pkg->[4];
    }
    print "\n";
    if( $status == 1 ) {
      print "PLEASE PRESS A KEY ON THE DEVICE TO BE ADDED\n";
    }
    $stopreceive = 1 if( grep( $status == $_, 3, 5, 6, 7 ) );
    return;
  }

  if( ($pkg->[1] == 4 ) && ($pkg->[5] == 0x85) && ($pkg->[6] == 3 ) ) {
    print "association report from unit ". ($pkg->[3]);
    print ", group ".($pkg->[7]);
    print ", max assoc. ".($pkg->[8]);
    print ", current assoc. ".($pkg->[9]);
    print ": ".join( " ", pkg->[10..100] );
    print "\n";
    return;
  }

  print "got packet: ";
  foreach my $byte (@$pkg) {
    print sprintf( "%X ", $byte );
  }
  print "\n";
}



=head1 NAME

ZWave::Controller - The great new ZWave::Controller!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use ZWave::Controller;

    my $foo = ZWave::Controller->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head2 function1

=cut

sub function1 {
}

=head2 function2

=cut

sub function2 {
}

=head1 AUTHOR

Todd Rinaldo, C<< <toddr at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-zwave-controller at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=ZWave-Controller>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc ZWave::Controller


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=ZWave-Controller>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/ZWave-Controller>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/ZWave-Controller>

=item * Search CPAN

L<http://search.cpan.org/dist/ZWave-Controller/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2010 Todd Rinaldo.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of ZWave::Controller
