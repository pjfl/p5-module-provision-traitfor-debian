package Module::Provision::TraitFor::Debian;

use 5.010001;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 3 $ =~ /\d+/gmx );

use Class::Usul::Constants  qw( EXCEPTION_CLASS NUL OK PREFIX SPC TRUE );
use Class::Usul::File;
use Class::Usul::Functions  qw( ensure_class_loaded io
                                is_arrayref squeeze throw trim );
use Class::Usul::Types      qw( HashRef NonEmptySimpleStr Object );
use Debian::Control;
use Debian::Control::Stanza::Binary;
use Debian::Dependency;
use Debian::Rules;
use Email::Date::Format     qw( email_date );
use English                 qw( -no_match_vars );
use File::DataClass::Types  qw( Path );
use File::ShareDir;
use Text::Format;
use Unexpected::Functions   qw( PathNotFound );
use Moo::Role;

requires qw( appldir config distname dist_version
             info license_keys load_meta run_cmd );

has 'ctrldir'      => is => 'lazy', isa => Path, coerce => TRUE,
   builder         => sub { $_[ 0 ]->appldir->catdir( 'var', 'etc' ) };

has 'debconf_path' => is => 'lazy', isa => Path, coerce => TRUE,
   builder         => sub { $_[ 0 ]->appldir->catfile( '.provision.json' ) };

has 'debconfig'    => is => 'lazy', isa => HashRef, builder => sub {
   $_[ 0 ]->debconf_path->exists or return {};
   Class::Usul::File->data_load( paths => [ $_[ 0 ]->debconf_path ] ) };

has 'dh_share_dir' => is => 'lazy', isa => Path, coerce => TRUE,
   builder         => sub { File::ShareDir::dist_dir( 'DhMakePerl' ) };

has 'dh_ver'       => is => 'lazy', isa => NonEmptySimpleStr,
   builder         => sub { $_[ 0 ]->debconfig->{dh_ver} // '7' };

has 'install_base' => is => 'lazy', isa => Path, coerce => TRUE,
   builder => sub { $_[ 0 ]->path_prefix->catdir
      ( (lc $_[ 0 ]->distname), 'v'.$_[ 0 ]->short_ver.'p'.$_[ 0 ]->phase ) };

has 'path_prefix'  => is => 'lazy', isa => Path, coerce => TRUE,
   builder         => sub { $_[ 0 ]->debconfig->{path_prefix} // PREFIX };

has 'phase'        => is => 'lazy', isa => NonEmptySimpleStr,
   builder         => sub { $_[ 0 ]->debconfig->{phase} // '1' };

has 'short_ver'    => is => 'lazy', isa => NonEmptySimpleStr, builder => sub {
   (my $v = $_[ 0 ]->dist_version) =~ s{ \. \d+ \z }{}mx; $v };

my $_bin_file = sub {
   return $_[ 0 ]->install_base->catdir( 'bin' )->catfile( $_[ 1 ] );
};

my $_abs_prog_path = sub {
   my ($self, $cmd) = @_; my ($prog, @args) = split SPC, $cmd || NUL;

   return join SPC, $self->$_bin_file( $prog ), @args;
};

my $_main_dir = sub {
   return $_[ 0 ]->appldir;
};

my $_add_debian_depends = sub {
   my ($self, $control) = @_; my $bin = $control->binary->Values( 0 );

   my $debconf = $self->debconfig; my $src = $control->source;

   exists $debconf->{debian_depends}
      and $bin->Depends->add( @{ $debconf->{debian_depends} } );

   exists $debconf->{debian_build_depends}
      and $src->Build_Depends->add( @{ $debconf->{debian_build_depends} } );

   exists $debconf->{debian_build_depends_indep}
      and $src->Build_Depends_Indep->add
         ( @{ $debconf->{debian_build_depends_indep} } );

   return;
};

my $_debian_dir = sub {
   return $_[ 0 ]->$_main_dir->catdir( 'debian' );
};

my $_debian_file = sub {
   return $_[ 0 ]->$_debian_dir->catfile( $_[ 1 ] );
};

my $_get_homepage = sub {
   my $link = $_[ 0 ]->debconfig->{permalink}
           // 'https:://metacpan.org/release';

   return sprintf '%s/%s/', $link, $_[ 0 ]->distname;
};

my $_get_maintainer = sub {
   my $self = shift; my $conf = $self->config;

   return sprintf '%s <%s>', $conf->author, $conf->author_email;
};

my $_license_content = sub {
   my ($self, $licenses, $maintainer) = @_; my @res = ();

   my $formatter = Text::Format->new; $formatter->leftMargin( 2 );

   for my $license (keys %{ $licenses }) {
      my $class = "Software::License::${license}"; ensure_class_loaded $class;

      my $swl  = $class->new( { holder => $maintainer } );
      my $text = $formatter->format( $swl->fulltext );

      $text =~ s{ \A \z }{ .}gmx; push @res, NUL, "License: ${license}", $text;
   }

   return \@res;
};

my $_postrm_content = sub {
   my $self = shift; my $debconf = $self->debconfig;

   exists $debconf->{uninstall_cmd} or return [];

   # TODO: Add the triggering of the reinstallation of the previous version
   my $cmd  = $self->$_abs_prog_path( $debconf->{uninstall_cmd} );
   my $subd = $self->install_base->basename;
   my $appd = $self->install_base->parent;
   my $papd = $appd->parent;

   length $appd < 2 and throw "Insane uninstall directory: ${appd}";
   $subd !~ m{ v \d+ \. \d+ p \d+ }mx
      and throw "Path ${subd} does not match v\\d+\\.\\d+p\\d+";

   return [ "${cmd} && \\",
            "   cd ${appd} && \\",
            "   test -d \"${subd}\" && rm -fr ${subd} ; rc=\${?}",
            "[ \${rc} -eq 0 ] && cd ${papd} && test -d \"${appd}\" && \\",
            "   rmdir ${appd} 2>/dev/null", ];
};

my $_shell_script = sub {
   my ($self, $car) = @_;

   $car and not is_arrayref $car
        and $car = [ $self->$_abs_prog_path( $car ).'; rc=${?}' ];

   return ('#!/bin/sh', @{ $car // [] }, 'exit ${rc:-1}');
};

my $_create_debian_changelog = sub {
   my ($self, $control) = @_;

   my $dh_ver_extn = $self->debconfig->{dh_ver_extn} // '-1';
   my $distro      = $self->debconfig->{distribution_type} // 'unstable';
   my $urgency     = $self->debconfig->{urgency} // 'low';
   my $io          = $self->$_debian_file( 'changelog' );
   my $src         = $control->source;

   $io->print( sprintf "%s (%s) %s; urgency=%s\n\n",
               $src->Source, $self->dist_version.$dh_ver_extn,
               $distro, $urgency );
   $io->print( "  * Initial Release.\n\n" );
   $io->print( sprintf " -- %s  %s\n", $src->Maintainer, email_date( time ) );
   return;
};

my $_create_debian_copyright = sub {
   my ($self, $control) = @_; my (@res, %licenses);

   my $year       = 1900 + (localtime)[ 5 ];
   my $maintainer = $control->source->Maintainer;
   my $licenses   = [ $self->load_meta( $self->ctrldir )->licenses ];
   my $license    = $self->license_keys->{ $licenses->[ 0 ] }
      or throw 'Unknown copyright license';
   my %fields     = ( Name       => $self->distname,
                      Maintainer => $maintainer,
                      Source     => $self->$_get_homepage );

   push @res, $self->debconfig->{dh_format_spec} // 'Format-Specification: http://svn.debian.org/wsvn/dep/web/deps/dep5.mdwn?op=file&rev=135';

   for (grep { defined $fields{ $_ } } keys %fields) {
      push @res, "$_: ".$fields{ $_ };
   }

   push @res, NUL, 'Files: *', "Copyright: ${maintainer}";

   ref $license and $license = $license->[ -1 ];

   if ($license ne 'Perl_5') { $licenses{ $license } = 1 }
   else { $licenses{'Artistic_1_0'} = $licenses{'GPL_1'} = 1 }

   push @res, 'License: '.(join ' or ', keys %licenses);

   # debian/* files information - We default to the module being
   # licensed as the super-set of the module and Perl itself.
   $licenses{'Artistic_1_0'} = $licenses{'GPL_1'} = 1;

   push @res, NUL, 'Files: debian/*', "Copyright: ${year}, ${maintainer}";
   push @res, 'License: '.(join ' or ', keys %licenses);
   push @res, @{ $self->$_license_content( \%licenses, $maintainer ) };

   $self->$_debian_file( 'copyright' )->println( @res );
   return;
};

my $_create_debian_maintainers = sub {
   my $self = shift; my $debconf = $self->debconfig;

   $debconf->{post_install_cmd} and $self->$_debian_file( 'postinst' )
           ->println( $self->$_shell_script( $debconf->{post_install_cmd} ) )
           ->chmod( 0750 );

   $self->$_debian_file( 'postrm' )
        ->println( $self->$_shell_script( $self->$_postrm_content ) )
        ->chmod( 0750 );
   return;
};

my $_create_debian_rules = sub {
   my $self   = shift;
   my $path   = $self->$_debian_file( 'rules' );
   my $rules  = Debian::Rules->new( $path->name );
   my $file   = $self->debconfig->{rules_file} // 'rules.dh7.tiny';
   my $source = $self->dh_share_dir->catfile( $file );

   $source->exists or throw PathNotFound, [ $source ];
   $self->info( 'Using rules '.$source->basename ); $rules->read( $source );

   my @lines = @{ $rules->lines }; my $line1 = shift @lines;

   unshift @lines, $line1, "\n",
      "override_dh_auto_configure:\n",
      "\tdh_auto_configure -- install_base=".$self->install_base."\n", "\n",
      "override_dh_pysupport:\n";

   $rules->lines( \@lines ); $rules->write; $path->chmod( 0750 );
   return $rules;
};

my $_create_debian_watch = sub {
   my $self = shift; my $io = $self->$_debian_file( 'watch' );

   my $version_re = 'v?(\d[\d.-]+)\.(?:tar(?:\.gz|\.bz2)?|tgz|zip)';

   $io->println( sprintf "version=3\n%s   .*/%s-%s\$",
                 $self->$_get_homepage, $self->distname, $version_re );
   return;
};

my $_discover_debian_utility_deps = sub {
   my ($self, $control, $rules) = @_;

   my $deps = $control->source->Build_Depends;
   my $bin  = $control->binary->Values( 0 );

   $deps->remove( 'quilt', 'debhelper' );

   # Start with the minimum
   $deps->add( Debian::Dependency->new( 'debhelper', $self->dh_ver ) );

   if ($control->is_arch_dep) { $deps->add( 'perl' ) }
   else { $control->source->Build_Depends_Indep->add( 'perl' ) }

   # Some mandatory dependencies
   my $bin_deps = $bin->Depends;

   not $control->is_arch_dep and $bin_deps += '${shlibs:Depends}';

   $bin_deps += '${misc:Depends}, ${perl:Depends}';
   return;
};

my $_set_debian_binary_data = sub {
   my ($self, $control, $pkgname, $arch) = @_; my $bin = $control->binary;

   $bin->FETCH( $pkgname )
      or $bin->Push( $pkgname => Debian::Control::Stanza::Binary->new( {
         Package => $pkgname } ) );

   my $binval = $bin->Values( 0 ); $binval->Architecture( $arch );

   my $abstract = $self->module_abstract or throw 'No dist abstract';

   $binval->short_description( $abstract );

   my $desc = $self->module_metadata->pod( 'Description' );

   $desc and $desc =~ s{ L\< ([^\>]+) \> }{$1}gmx
         and $desc =~ s{ [\n] }{ }gmx
         and $binval->long_description( trim squeeze $desc );

   return $binval;
};

my $_set_debian_package_defaults = sub {
   my ($self, $control) = @_;

   my $src = $control->source; my $pkgname = lc $self->distname.'-perl';

   $pkgname =~ s{ [^-.+a-zA-Z0-9]+ }{-}gmx;

   $src->Source           ( $pkgname   );
   $src->Section          ( 'perl'     );
   $src->Priority         ( 'optional' );
   $src->Homepage         ( $self->$_get_homepage );
   $src->Maintainer       ( $self->$_get_maintainer );
   $src->Standards_Version( $self->debconfig->{dh_stdversion} // '3.9.1' );

   my $binval = $self->$_set_debian_binary_data( $control, $pkgname, 'any' );

   $self->info( sprintf "Found %s %s (%s arch=%s)\n",
                $self->distname, $self->dist_version,
                $pkgname, $binval->Architecture );
   $self->info( sprintf "Maintainer %s\n", $src->Maintainer );
   return;
};

my $_update_debian_file_list = sub {
   my ($self, $control, %p) = @_;

   my $src = $control->source; my $pkgname = $src->Source;

   while (my ($file, $new_content) = each %p) {
      @{ $new_content } or next; my (@existing_content, %uniq_content);

      my $pkg_file = $self->$_debian_file( "${pkgname}.${file}" );

      if ($pkg_file->is_readable) {
         @existing_content = $pkg_file->chomp->getlines;

         $uniq_content{ $_ } = 1 for (@existing_content);
      }

      $uniq_content{ $_ } = 1 for (@{ $new_content });

      for (@existing_content, @{ $new_content }) {
         exists $uniq_content{ $_ } or next;
         delete $uniq_content{ $_ };
         $pkg_file->println( $_ );
      }
   }

   return;
};

my $_create_debian_package = sub {
   my $self = shift; my $control = Debian::Control->new;

   $self->$_debian_dir->mkdir( 0750 )->rmtree( { keep_root => TRUE } );
   $self->$_debian_file( 'compat' )->println( $self->dh_ver );
   $self->$_set_debian_package_defaults( $control );
   $self->$_add_debian_depends         ( $control );
   $self->$_create_debian_changelog    ( $control );
   $self->$_create_debian_copyright    ( $control );
   $self->$_create_debian_watch;
   $self->$_create_debian_maintainers;

   my $rules = $self->$_create_debian_rules;

   # Now that rules are there, see if we need some dependency for them
   $self->$_discover_debian_utility_deps( $control, $rules );
   $control->write( $self->$_debian_file( 'control' )->name );

   my $docs = [ $self->$_main_dir->catfile( 'README.md' ) ];

   $self->$_update_debian_file_list( $control, docs => $docs );

   my $cmd  = [ qw( fakeroot dh binary ) ];

   $self->info( $self->run_cmd( $cmd, { err => 'out' } )->out );
   return;
};

sub build : method {
   my $self = shift;
   my $dir  = $self->debconfig->{localdir} // 'local';
   my $args = { err => 'stderr', out => 'stdout' };

#   $ENV{BUILDING_DEBIAN} = TRUE; # Was in original
#   $ENV{DEB_BUILD_OPTIONS} = 'nocheck';
#   $ENV{DEVEL_COVER_NO_COVERAGE} = TRUE;     # Devel::Cover
   $self->run_cmd( [ 'cpanm', '-L', $dir, 'local::lib' ], $args );
   delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) }; # App::Ack issue 493
   $self->run_cmd( [ 'cpanm', '-L', $dir, '--installdeps', '.' ], $args );

   my $inc     = io( [ $dir, 'lib', 'perl5'   ] );
   my $profile = io( [ $dir, 'etc', 'profile' ] )->assert_filepath;
   my $cmd     = [ $EXECUTABLE_NAME, '-I', $inc, "-Mlocal::lib=${dir}" ];

   $self->run_cmd( $cmd, { err => 'stderr', out => $profile } );
   $self->$_create_debian_package;
   return OK;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Module::Provision::TraitFor::Debian - Build a Debian installable archive of an application

=head1 Synopsis

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

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head2 build - Build a Debian installable archive of an application

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

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
