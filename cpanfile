requires "Alt::DhMakePerl::installable" => "v0.1.1";
requires "Class::Usul" => "v0.55.0";
requires "Email::Date::Format" => "1.005";
requires "File::DataClass" => "v0.55.0";
requires "File::ShareDir" => "1.102";
requires "Moo" => "1.006000";
requires "Text::Format" => "0.59";
requires "namespace::autoclean" => "0.22";
requires "perl" => "5.010001";

on 'build' => sub {
  requires "Module::Build" => "0.4004";
  requires "Test::Requires" => "0.06";
  requires "version" => "0.88";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};
