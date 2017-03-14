#!/usr/bin/perl

BEGIN {
	my $libpath = './Modules';
	unshift(@INC, $libpath);    
	
	########### TODO ###########
}

# Подключаем основные модули
use strict;
use warnings;
use Data::Dumper;
use Core;
use Model;
use DBI;
#use Utils qw/&DateTime True False/;

my %mainData;
my ($key, $value);
our %config;
my $core;
my $model;

### Подтягиваем конфиг
require "./config/config.cnf";

###  Подключем ДБ
my $db = DBI->connect("DBI:$config{dbtype_ipnp}:database=$config{dbname_ipnp};host=$config{host_ipnp}", "$config{user_ipnp}", "$config{pass_ipnp}") or die "Unable connect to IPNP - MySQL-server\n";
    $db->do("set names $config{dbcharset_ipnp}");
my $dbl = DBI->connect("DBI:$config{dbtype_ipplan}:database=$config{dbname_ipplan};host=$config{host_ipplan}", "$config{user_ipplan}", "$config{pass_ipplan}") or die "Unable connect to IPPLAN - MySQL-server \n";
    $dbl->do("set names $config{dbcharset_ipplan}");

##########################################################################################################
##########################################################################################################
##########################################################################################################


$core = Core->New(
				GlobalConf => \%config,
				);

$model = Model->New(
				DBH_IPPLAN => $dbl,
				DBH_IPNP => $db,
				);

my %regionData = $model->getRegionList();

$core->createDB(%regionData);

exit;
