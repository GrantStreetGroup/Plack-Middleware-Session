#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Temp qw(tempdir);

use Test::Requires qw(DBI DBD::SQLite MIME::Base64 Storable);
use Test::More;

use Plack::Request;
use Plack::Session;
use Plack::Session::State::Cookie;
use Plack::Session::Store::DBI;

use t::lib::TestSession;

my $tmp  = tempdir(CLEANUP => 1);
my $file = File::Spec->catfile($tmp, "006_basic_w_dbi_store.db");
my $dbh  = DBI->connect( "dbi:SQLite:$file", undef, undef, {RaiseError => 1, AutoCommit => 1} );
$dbh->do(<<EOSQL);
CREATE TABLE sessions (
    id CHAR(72) PRIMARY KEY,
    session_data TEXT
);
EOSQL

tests_per_dbh($dbh);

my $file2 = File::Spec->catfile($tmp, "006_basic_w_dbi_store.db");
my $dbh2  = DBI->connect( "dbi:SQLite:$file2", undef, undef, {RaiseError => 1, AutoCommit => 1} );
# Building the table with these weird names will simultaneously prove that we
# accept custom table and column names while also demonstrating that we do
# quoting correctly, which the previous code did not.
$dbh2->do(<<EOSQL2);
CREATE TABLE 'insert' (
    'where' CHAR(72) PRIMARY KEY,
    'set' TEXT
);
EOSQL2

tests_per_dbh($dbh2,
    table_name  => 'insert',
    id_column   => 'where',
    data_column => 'set',
);

sub tests_per_dbh {
    my ($dbh, %store_opts) = shift;

    t::lib::TestSession::run_all_tests(
        store  => Plack::Session::Store::DBI->new( dbh => $dbh, %store_opts ),
        state  => Plack::Session::State->new,
        env_cb => sub {
            open my $in, '<', \do { my $d };
            my $env = {
                'psgi.version'    => [ 1, 0 ],
                'psgi.input'      => $in,
                'psgi.errors'     => *STDERR,
                'psgi.url_scheme' => 'http',
                SERVER_PORT       => 80,
                REQUEST_METHOD    => 'GET',
                QUERY_STRING      => join "&" => map { $_ . "=" . $_[0]->{ $_ } } keys %{$_[0] || +{}},
            };
        },
    );

    t::lib::TestSession::run_all_tests(
        store  => Plack::Session::Store::DBI->new( get_dbh => sub { $dbh }, %store_opts  ),
        state  => Plack::Session::State->new,
        env_cb => sub {
            open my $in, '<', \do { my $d };
            my $env = {
                'psgi.version'    => [ 1, 0 ],
                'psgi.input'      => $in,
                'psgi.errors'     => *STDERR,
                'psgi.url_scheme' => 'http',
                SERVER_PORT       => 80,
                REQUEST_METHOD    => 'GET',
                QUERY_STRING      => join "&" => map { $_ . "=" . $_[0]->{ $_ } } keys %{$_[0] || +{}},
            };
        },
    );


    $dbh->disconnect;
}


done_testing;
