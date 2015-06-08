requires "Archive::Tar" => "2.02";
requires "Class::Usul" => "v0.62.0";
requires "Module::Provision" => "v0.39.0";
requires "Moo" => "2.000001";
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
