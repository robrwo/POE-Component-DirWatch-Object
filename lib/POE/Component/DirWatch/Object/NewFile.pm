package POE::Component::DirWatch::Object::NewFile;
use strict;
use warnings;
use Moose;

our $VERSION = "0.02";

extends 'POE::Component::DirWatch::Object';
has 'seen_files' => (is => 'rw', isa => 'HashRef');
has 'edited'     => (is => 'rw', isa => 'Bool', required => 1, default => 0);

#--------#---------#---------#---------#---------#---------#---------#---------#

#clean seen files from dispatch list
before '_dispatch' => sub{
    my $self = shift;
    my $seen = $self->seen_files;
    my @n_list = grep{ !exists($seen->{ $_->[1] }) } $self->dispatch_list;
    
    #if not reprocessing change the last change date every cycle so that if
    # turned on during runtime it only picks up edited files going forward
    unless($self->edited){ $seen->{$_} = (stat($_))[9] foreach keys %$seen; }

    $seen->{$_->[1]} = (stat($_->[1]))[9] foreach @n_list;

    # yeah i could do this with less vars but honestly, fuck it
    $self->dispatch_list( \@n_list );
};

#clean seen files that no longer exist or have been modified
before '_poll' => sub {
    my $self = shift;
    my $seen = $self->seen_files;

    if($self->edited){
	my %n_seen = map {$_ => $seen->{$_}} 
	    grep { -e $_  && $seen->{$_} == (stat($_))[9] } keys %$seen;
	$self->seen_files(\ %n_seen);
    } else{
    	my %n_seen = map {$_ => $seen->{$_}} grep { -e $_  } keys %$seen;
	$self->seen_files(\ %n_seen);
    }
};



1;

__END__;

#--------#---------#---------#---------#---------#---------#---------#---------#


=head1 NAME

POE::Component::DirWatch::Object::NewFile

=head1 SYNOPSIS

  use POE::Component::DirWatch::Object::NewFile;

  #$watcher is a PoCo::DW:Object::NewFile 
  my $watcher = POE::Component::DirWatch::Object::NewFile->new
    (
     alias      => 'dirwatch',
     directory  => '/some_dir',
     filter     => sub { $_[0] =~ /\.gz$/ && -f $_[1] },
     callback   => \&some_sub,
     interval   => 1,
     edited     => 1,   #pick up files that have been edited since last poll
    );

  $poe_kernel->run;

=head1 DESCRIPTION

POE::Component::DirWatch::Object::NewFile extends DirWatch::Object in order to 
exclude files that have already been processed 

=head1 Accessors

=head2 seen_files

Read-write. Will return a hash ref in with keys will be the full path 
of all previously processed documents that still exist in the file system and the
values are the last changed dates of the files.

=head2 edited

Read-Write. A boolean value, if set to true it will re-process edited files. If changed 
during runtime to true it will only pick up files that whose last edited date changed
after C<edited> was set to true. 

=head1 Extended methods

=head2 dispatch

C<before 'dispatch'> the dipatch list is compared against C<$self-E<gt>seen_files>
and previously seen files are dropped from that list. at the end it adds all new
files to the list of known files.

=head2 poll

C<before 'poll'> the list of known files is checked and if any of the files no 
longer exist they are removed from the list of known files to avoid the list 
growing out of control. This makes a kind-of bug, look below.

=head2 meta

Keeping tests happy.

=head1 SEE ALSO

L<POE::Component::DirWatch::Object>, L<Moose>

=head1 AUTHOR

Guillermo Roditi, <groditi@cpan.org>

=head1 BUGS

If a file is created and deleted between polls it will never be seen. Also if a file
is edited more than once in between polls it will never be picked up.

Please report any bugs or feature requests to
C<bug-poe-component-dirwatch-object at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-DirWatch-Object>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::DirWatch::Object::NewFile

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-DirWatch-Object>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-DirWatch-Object>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-DirWatch-Object>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-DirWatch-Object>

=back

=head1 ACKNOWLEDGEMENTS

People who answered way too many questions from an inquisitive idiot:

=over 4

=item #PoE & #Moose

=item Matt S Trout <mst@shadowcatsystems.co.uk>

=item Rocco Caputo

=back

=head1 COPYRIGHT

Copyright 2006 Guillermo Roditi.  All Rights Reserved.  This is
free software; you may redistribute it and/or modify it under the same
terms as Perl itself.

=cut

