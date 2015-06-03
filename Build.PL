use strict;
use warnings;

use Module::Build 0.4004;

sub testing { $ENV{AUTOMATED_TESTING} || $ENV{PERL_CPAN_REPORTER_CONFIG}
                                      || $ENV{PERL5_CPANPLUS_IS_VERSION} }
sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

my $perl_ver = 5.010001;
my $name     = 'Module-Provision-TraitFor-Debian'; $name =~ s{ - }{::}gmx;
my $prereqs  = {
  'build_requires' => {
    'Module::Build' => '0.4004',
    'Test::Requires' => '0.06',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'requires' => {
    'Alt::DhMakePerl::installable' => 'v0.1.0',
    'Class::Usul' => 'v0.62.0',
    'Email::Date::Format' => '1.005',
    'File::DataClass' => 'v0.55.0',
    'File::ShareDir' => '1.102',
    'Module::Provision' => 'v0.39.0',
    'Moo' => '2.000001',
    'Text::Format' => '0.59',
    'namespace::autoclean' => '0.22',
    'perl' => '5.010001'
  },
};

if ($] < $perl_ver) { # Not interested in reports below min perl ver
   testing or whimper "Minimum required Perl version is ${perl_ver}";
   $prereqs->{build_requires} = { %{ $prereqs->{configure_requires} } };
   $prereqs->{build_requires}->{ 'Test::Requires' } = 0.06;
   delete $prereqs->{requires};
}

Module::Build->new(
   'module_name' => $name,
   'notes'       => { min_perl_version => $perl_ver, testing => testing },
   %{ $prereqs },

)->create_build_script;

exit 0;
