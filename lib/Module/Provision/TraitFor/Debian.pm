package Module::Provision::TraitFor::Debian;

use 5.010001;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 8 $ =~ /\d+/gmx );

use Archive::Tar::Constant  qw( COMPRESS_GZIP );
use Class::Usul::Constants  qw( OK );
use Class::Usul::Functions  qw( ensure_class_loaded );
use Moo::Role;

requires qw( appldir chdir config run_cmd );

my $make_localarc = sub {
   my ($self, $localdir, $file) = @_; ensure_class_loaded 'Archive::Tar';

   my $args = { err => 'stderr', out => 'stdout' }; my $cmd;

   unless ($localdir->exists) {
      $cmd = [ 'cpanm', '-L', "${localdir}", 'local::lib' ];
      $self->run_cmd( $cmd, $args );
      delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) }; # App::Ack issue 493
      $cmd = [ 'cpanm', '-L', "${localdir}", '--installdeps', '.' ];
      $self->run_cmd( $cmd, $args );
   }

   my $arc = Archive::Tar->new; my $filter = sub { $_ !~ m{ [/\\] \. }mx };

   for my $path ($localdir->filter( $filter )->deep->all_files) {
      $arc->add_files( $path->abs2rel( $localdir->parent ) );
   }

   $self->info( 'Generating local tarball' );
   $arc->write( $file, COMPRESS_GZIP );
   return;
};

sub build : method {
   my $self     = shift;
   my $appldir  = $self->appldir;
   my $args     = { err => 'stderr', out => 'stdout' };
   my $localarc = $appldir->parent->catfile( 'local.tgz' );
   my $localdir = $appldir->catdir( $self->config->{localdir} // 'local' );
   my $builddir = $self->distname.'-'.$self->dist_version;

   $ENV{DEB_BUILD_OPTIONS} = 'nocheck';
#   $ENV{BUILDING_DEBIAN} = TRUE; # Was in original
#   $ENV{DEVEL_COVER_NO_COVERAGE} = TRUE;     # Devel::Cover

   $localarc->exists or $self->$make_localarc( $localdir, $localarc );
   $self->run_cmd( [ 'dzil', 'build' ], $args );
   $self->chdir( $appldir->catdir( $builddir ) );
   $self->run_cmd( [ 'tar', '-xzf', "${localarc}" ], $args );
   $self->run_cmd( [ 'fakeroot', 'dh', 'binary' ], $args );
   $self->chdir( $appldir );
   $self->run_cmd( [ 'dzil', 'clean' ], $args );
   return OK;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Module::Provision::TraitFor::Debian - Build a Debian installable archive of an application

=head1 Synopsis

   # In Module::Provision
   sub BUILD {
      my $self = shift;

      for my $plugin (@{ $self->plugins }) {
         if (first_char $plugin eq '+') { $plugin = substr $plugin, 1 }
         else { $plugin = "Module::Provision::TraitFor::${plugin}" }

         try   { Role::Tiny->apply_roles_to_object( $self, $plugin ) }
         catch {
            $_ =~ m{ \ACan\'t \s+ locate }mx or throw $_;
            throw 'Module [_1] not found in @INC', [ $plugin ];
         };
      }

      return;
   }

   # From the command line in an applications root directory
   module_provision -MDebian build

=head1 Description

Build a Debian installable archive of an application

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

=head2 build - Build a Debian installable archive of an application

Install L<local::lib>. Installs the applications dependencies into said local
library. Creates a profile setting up the environment to use the local lib
and then create a Debian package of the whole lot

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Archive::Tar>

=item L<Class::Usul>

=item L<Module::Provision>

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Module-Provision-TraitFor-Debian.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2015 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
