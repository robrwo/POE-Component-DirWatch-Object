package POE::Component::DirWatch::Object;
use strict;
use warnings;
use Moose;

our $VERSION = "0.04";
use File::Spec;
use DirHandle;
use Carp;
use POE;

#--------#---------#---------#---------#---------#---------#---------#---------#
##TODO: these should be ro. but idont kow how it works
has 'session'    => (is => 'rw', isa => 'Object', weak_ref => 1);
has 'dir_handle' => (is => 'rw', isa => 'Object');
has 'alias'      => (is => 'rw', isa => 'Str', required => 1, 
		     default => 'dirwatch');

has 'callback'  => (is => 'rw', isa => 'CodeRef', required => 1);
has 'directory' => (is => 'rw', isa => 'Str',     required => 1);
has 'interval'  => (is => 'rw', isa => 'Int',     required => 1, default => 1);
has 'filter'    => (is => 'rw', isa => 'CodeRef', required => 1, 
		    default => sub { sub{ -f $_[1]; } }); #holler
has 'dispatch_list'  => (is => 'rw', isa => 'ArrayRef', auto_deref => 1);


sub BUILD{
    my ($self, $args) = @_;

    my $s = POE::Session->create
	(
	 object_states  =>
	 [
	  $self,  {
		    _start   => '_start',
		    _stop    => '_stop',
		    shutdown => '_shutdown',
		    poll     => '_poll',
		    callback => '_callback',
		    dispatch => '_dispatch',
		   },
	 ]
	);

    $self->session($s);
}

#--------#---------#---------#---------#---------#---------#---------#---------#
sub _start{
    my ($self, $kernel) = @_[OBJECT, KERNEL];

    # set alias for ourselves and remember it
    $kernel->alias_set($self->alias);

    # open the directory handle
    $self->dir_handle(DirHandle->new($self->directory));
    croak("Can't open ".$self->directory().": $!\n") unless $self->dir_handle;

    # set up polling
    $kernel->delay(poll => $self->interval);
}


#--------#---------#---------#---------#---------#---------#---------#---------#
sub _stop{
    my $self = $_[OBJECT];

    # close the directory handle
    $self->dir_handle->close if $self->dir_handle;
}

#--------#---------#---------#---------#---------#---------#---------#---------#
sub _poll{
    my ($self, $kernel) = @_[OBJECT, KERNEL];

    # make sure we have a directory handle
    $self->dir_handle or croak "Need to run() before poll()\n";

    $self->dir_handle->rewind;	# rewind to directory start

    my @queue;
    # look for a file that matches our filter and report it
    for my $file ($self->dir_handle->read()) {
	my @params = ($file, File::Spec->catfile($self->directory, $file) );
	push(@queue, \@params) if $self->_filter(@params);
    }
    
    $self->dispatch_list( \@queue );
    $kernel->yield('dispatch');

    # arrange to be called again soon
    $kernel->delay(poll => $self->interval);
}

sub _dispatch{
    my ($self, $kernel) = @_[OBJECT, KERNEL];
    $kernel->yield(callback => @$_) foreach $self->dispatch_list;
}

sub _callback{
    my $self = $_[OBJECT];
    return $self->callback->(@_);
}

sub _filter{
    my $self = shift;  #fine to shift here
    return $self->filter->(@_);
}

#--------#---------#---------#---------#---------#---------#---------#---------#
sub _shutdown {
    my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];

    #cleaup heap, alias, alarms (no lingering refs n ish)
    %$heap = ();
    $kernel->alias_remove($self->alias);
    $kernel->alarm_remove_all();
}

#--------#---------#---------#---------#---------#---------#---------#---------#
1;

__END__;

=head1 NAME

POE::Component::DirWatch::Object - POE directory watcher object

=head1 SYNOPSIS

  use POE::Component::DirWatch::Object;

  #$watcher is a PoCo::DW:Object 
  my $watcher = POE::Component::DirWatch::Object->new
    (
     alias      => 'dirwatch',
     directory  => '/some_dir',
     filter     => sub { $_[0] =~ /\.gz$/ && -f $_[1] },
     callback   => \&some_sub,
     interval   => 1,
    );

  $poe_kernel->run;

=head1 DESCRIPTION

POE::Component::DirWatch::Object watches a directory for files. Upon finding
a file it will invoke the user-supplied callback function.

This module was primarily designed as an L<Moose>-based replacement for
 L<POE::Component::Dirwatch>. While all known functionality of the original is
meant to be covered in a similar way there is some subtle differences.

Its primary intended use is processing a "drop-box" style
directory, such as an FTP upload directory.

=head1 Public Methods

=head2 new( \%attrs)

=over 4

=item alias

The alias for the DirWatch session.  Defaults to C<dirwatch> if not
specified.

=item directory

The path of the directory to watch. This is a required argument.

=item interval

The interval waited between the end of a directory poll and the start of another.
 Default to 1 if not specified. 

WARNING: This is number NOT the interval between polls. A lengthy blocking callback, 
high-loads, or slow applications may delay the time between polls. You can see:
L<http://poe.perl.org/?POE_Cookbook/Recurring_Alarms> for more info.

=item callback

A reference to a subroutine that will be called when a matching
file is found in the directory.

This subroutine is called with two arguments: the name of the
file, and its full pathname. It usually makes most sense to process
the file and remove it from the directory.

This is a required argument.

=item filter

A reference to a subroutine that will be called for each file
in the watched directory. It should return a TRUE value if
the file qualifies as found, FALSE if the file is to be
ignored.

This subroutine is called with two arguments: the name of the
file, and its full pathname.

If not specified, defaults to C<sub { -f $_[1] }>.

=back

=head1 Accessors

Note: You should never have to use any of these unless you are subclassing.
For most tasks you should be able to implement any functionality you need without
ever dealing with these objects. That being said, hacking is fun.

=head2 alias

Read-only. Returns the alias of the POE session. Maybe allow a way to rename the 
session during runtime?

=head2 session

Read-only; Returns a reference to the actual POE session.
Please avoid this unless you are subclassing. Even then it is recommended that 
it is always used as C<$watcher-E<gt>session-E<gt>method> because copying the object 
reference around could create a problem with lingering references.

=head2 directory

Read-only; Returns the directory we are currently watching
TODO: allow dir to change during runtime

=head2 dir_handle

Read-only; Returns a reference to a L<DirHandle> object

=head2 filter

Read-Write; Returns the coderef being used to filter files.

=head2 interval

Read-Write; Returns the interval in seconds that the polling routine
wait after it is done running and before it runs again. This is NOT
the time between the start of polls, it is the time between the end of one 
poll and the start of another.

=head2 callback

Read-Write; Returns the coderef being called when a file is found.

=head2 dispatch_list

Read-Write; Returns a list of the files enqueued to be processed. Messing with this
C<before 'dispatch'> is the preferred way of messing with the list of files to be processed
other than C<filter>

=head1 Private methods

These methods are documented here just in case you subclass. Please
do not call them directly. If you are wondering why some are needed it is so 
Moose's C<before> and C<after> work.

=head2 _filter

Code provided because it's more explanatory.
C<sub _filter{ return shift-E<gt>filter-E<gt>(@_) }>

=head2 _callback

Code provided because it's more explanatory.
C<sub _filter{ return shift-E<gt>filter-E<gt>(@_) }>

=head2 _start

Runs when C<$poe_kernel-E<gt>run> is called. It will create a new DirHandle watching
to C<$watcher-E<gt>directory>, set the session's alias and schedule the first C<poll> event.

=head2 _poll

Triggered by the C<poll> event this is the re-occurring action. Every time it runs it will 
search for files, C<_filter()> them, store the matching files as a list and trigger the 
C<dispatch> event.

=head2 _dispatch

Triggered, by the C<dispatch> event this method will iterate through C<$self-E<gt>dispatch_list>
 and send a C<callback> event for every file in the dispatch list. 

=head2 _pause

This is a TODO. email with suggestions as to how you'd like it to work.

=head2 _resume

This is a TODO. email with suggestions as to how you'd like it to work.

=head2 _stop

Close that filehandle.

=head2 _shutdown

Delete the C<heap>, remove the alias we are using and remove all set alarms.

=head2 BUILD

Constructor. C<create()>s a L<POE::Session> and stores it in C<$self-E<gt>session>.

=head2 meta

Todo

=head1 TODO

=over 4

=item Use C<Win32::ChangeNotify> on Win32 platforms for better performance.

=item Spin the directory polling into an async operation.

=item Enable pause / resume functionality

=item Allow user to change the directory watched during runtime.

=item ImproveDocs

=item Write some tests. (after I read PDN and learn how)

=item Figure out why stringifying breaks things so I can add it

=item Figure out why taint mode fails

=back

=head1 Subclassing

Please see L<Moose> for the proper way to subclass this. And please remember to
shift $self out of @_ on any functions called by POE directly so that you don't screw
up the named @_ positions (@_[KERNEL, HEAP, ...])

Also check out L<POE::Component::DirWatch::Object::NewFile> for a simple example of
how to extend functionality.

=head1 SEE ALSO

L<POE>, L<POE::Session>, L<POE::Component>, L<POE::Component::DirWatch>, L<Moose>

=head1 AUTHOR

Guillermo Roditi, <groditi@cpan.org>

Based on the L<POE::Component::Dirwatch> code by:
Eric Cholet, <cholet@logilune.com>
(I also copy pasted some POD)

=head1 BUGS

Holler?

Please report any bugs or feature requests to
C<bug-poe-component-dirwatch-object at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-DirWatch-Object>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::DirWatch::Object

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

=item Charles Reiss

=back

=head1 COPYRIGHT

Copyright 2006 Guillermo Roditi.  All Rights Reserved.  This is
free software; you may redistribute it and/or modify it under the same
terms as Perl itself.

=cut
