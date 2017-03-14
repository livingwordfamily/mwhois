package DB;

use strict;
use Exporter qw(import); # Обязательная строка для экспорта имен
use warnings;
use Data::Dumper;
use DBI qw(:sql_types);
use Utils qw(False True);

our @ISA         = qw(Exporter); # -//-
our $VERSION     = 1.00;
our @EXPORT_OK   = qw(&_getSelect &Logging);
our %EXPORT_TAGS = ( DEFAULT => [qw(&New)] );

my ($class, %opts, @args, $arg, $self, $sth);

sub New {
	($class, %opts) = @_;
	$self = bless({%opts}, $class);
	$self->{className} = 'DB';
	$self->{version} = '1.0';
	$self->{child} = (ref($self) =~ /::(.*)/)[0];
	# Берем имя таблици из названия модуля
	my @ref = split(/::/, ref($self));
	$self->{table} = lc(pop(@ref)) if !exists $self->{table};
	$self->_handle_error('Database type not set') if ((!exists $opts{dbType} or $opts{dbType} eq '') && (!exists $opts{DBH} or $opts{DBH} eq ''));
	$self->_handle_error('Database name not set') if ((!exists $opts{dbName} or $opts{dbName} eq '') && (!exists $opts{DBH} or $opts{DBH} eq ''));
	$self->_handle_error('Database host not set') if ((!exists $opts{dbHost} or $opts{dbHost} eq '') && (!exists $opts{DBH} or $opts{DBH} eq ''));
	$self->_handle_error('Database user not set') if ((!exists $opts{dbUser} or $opts{dbUser} eq '') && (!exists $opts{DBH} or $opts{DBH} eq ''));
	$self->_handle_error('Database password not set') if ((!exists $opts{dbPasswd} or $opts{dbPasswd} eq '') && (!exists $opts{DBH} or $opts{DBH} eq ''));
   	#===============================================================================#
	# Подключаемся к базе и выбираем всё с чем мы будем работать:
	$self->{DBH} = DBI->connect("DBI:$opts{dbType}:database=$opts{dbName};host=$opts{dbHost}", "$opts{dbUser}", "$opts{dbPasswd}") or $self->_handle_error(DBI->errstr) if (!exists $opts{DBH} or $opts{DBH} eq '');
	$self->{DBH}->do("set names $opts{dbCharset}") if (!exists $opts{DBH} or $opts{DBH} eq '');
	$self->{DBH}->{RaiseError} = 1;
	$self->{DBH}->{PrintError} = 0;
#	$self->{DBH}->trace(2); # Включить DBI дебаг (трасировку запросов)
	#$self->{DBH}->{HandleError} = \$self->_handle_error();
	$self->_getTableStructure if (defined $opts{autoDiscover} && $opts{autoDiscover} =~ /true|1|yes/i);
	return $self;
}

#	// получить одну запись
#	function getOneRow(){
#		$this->_getQuery();
#		if(!isset($this->dataResult) OR empty($this->dataResult)) return false;
#		return $this->dataResult[0];
#	}

	# получить запись по id
sub getRowById() {
	($self, @args) = @_;
	my $id;
	my @result;
	# Разбор передаваемых параметров и атребутов
	if (scalar @args > 1) {

		foreach (@args) {
			if (ref $_ eq 'HASH') {
				%opts = %{$_};
			} else {
				$id = $_;
			}
		}
			
	} elsif (scalar @args == 1) {
		$id = shift(@args);
	} else {
		$self->_handle_error("Invalid get params");
	}

	# Определяем поле по которому будим выберать данные
	my $id_field = ((defined $opts{idField}) && ($opts{idField} ne '')) ? $opts{idField} : 'id';
	eval {
		$sth = $self->{DBH}->prepare("SELECT * FROM $self->{table} WHERE $id_field = ?");
		$sth->execute("$id");
		if ($sth->rows() == 1) {
				@result = @{${$sth->fetchall_arrayref()}[0]};
			} else {
				@result = @{$sth->fetchall_arrayref()};
			}

	} or $self->_handle_error($self->{DBH}->errstr());
	return @result;
}

# получить все записи
sub getAllRows(){
	($self, %opts) = @_;
	$self->_getQuery(%opts);
	return (!defined $self->{dataResult} || $self->{dataResult} eq '') ? 'false' : @{$self->{dataResult}};
}

# Обычный запрос без генерации чего либо возвращает многомерный масив
sub rawQuery() {
	($self, my $sql, @args) = @_;

	my $result;

	eval {
		$sth = $self->{DBH}->prepare($sql);
		$result = $sth->execute(@args);
		#print "RES => $result = ".$sth->rows();
	} or $self->_handle_error($self->{DBH}->errstr());


	if ($sql =~ /SELECT/i){
		return @{$sth->fetchall_arrayref()} if !$self->{DBH}->errstr();
	} elsif ($sql =~ /INSERT/i){
		return $self->{DBH}->{mysql_insertid};
	} else {
		return $result;
	}
}

# Обычный запрос без генерации чего либо, возвращает хешреф
sub rawQueryHash() {
	($self, my $sql, @args) = @_;

	my $result;

	eval {
		$sth = $self->{DBH}->prepare($sql);
		$result = $sth->execute(@args);
	} or $self->_handle_error($self->{DBH}->errstr());

	if ($sql =~ /SELECT/i){
		if (!$self->{DBH}->errstr()) {
			
			#my $id_field = ((defined $opts{idField}) && ($opts{idField} ne '')) ? $opts{idField} : 'id';
			if ($sth->rows() == 1) {
				my %hash = %{$sth->fetchall_hashref('id')};
				my $key = (keys %hash)[0];
				$self->{Result} = $hash{$key};
				#warn Dumper $self->{Result};
				return %{$self->{Result}};
				#return %{$hash{$key}};
			} else {
				$self->{Result} = $sth->fetchall_hashref('id');
			 	return %{$self->{Result}};
			}
		}
	} else {
		return $result;
	}
	# $dbh->{FetchHashKeyName} = 'NAME_lc';
}

# Обычный запрос без генерации чего либо
sub rawMultiInsert() {
	($self, my $sql, @args) = @_;
#	print Dumper(@args);
	my $result;
	my (@values, $values);

#		($sql, my $valuesTemplate) = ($sql =~ /(.*VALUES\s+?)(\(.*\))(\s+|\n+)?$/gs);
#		for (@args) {
#			$values = $valuesTemplate;
#			for (@{$_}) {
#				$_ = $self->{DBH}->quote("$_");
#				$values =~ s/(\?)/$_/;
#			}
#			push(@values, $values);
#		}
#		print join(",\n", @values);
#		print "\n";



#		eval {
#			$sth = $self->{DBH}->prepare($sql);
#			$result = $sth->execute(@args);
#		} or $self->_handle_error($self->{DBH}->errstr());

#		if ($sql =~ /SELECT/i){
#			return @{$sth->fetchall_arrayref()} if !$self->{DBH}->errstr();
#		} else {
#			return $result;
#		}


	return @{$sth->fetchall_arrayref()} if !$self->{DBH}->errstr();
}

# запись в базу данных
sub insert() {
	($self, %opts) = @_;
	my @placeHolder;
	my @filds;
	my @fildsData;
	my $strPlaceHolder;
	my $strFilds;
	my $insertID = 0;

	# Генерим сам запрос с данными
	foreach (sort keys %{$self->{fieldsTable}}) {
		$_ =~ s/^\d+_//;
		#print "$_\n";
		if (defined $self->{"$_"} && $self->{"$_"} ne '') {
			push @placeHolder, '?';
			push @filds, "`$_`";
			push @fildsData, $self->{"$_"};
		}
	}

	# Тут все понятно :)
	$strPlaceHolder = join(', ', @placeHolder);
	$strFilds = join(', ', @filds);

	# Исполняем запрос
	eval {
		$sth = $self->{DBH}->prepare("INSERT INTO `$self->{table}` ($strFilds) VALUES ($strPlaceHolder)");
		#$sth->execute(@fildsData);
		$insertID = $self->{DBH}->{mysql_insertid} if ($sth->execute(@fildsData));
	} or $self->_handle_error($self->{DBH}->errstr());	

	return $insertID;

}

	# обновление записи. Происходит по ID
sub update(){
	($self, %opts) = @_;
	my (@placeHolder, @fildsData, $strPlaceHolder, $whereID, $result, $rows, $id_field);
	my $condition = '';
#	print "update";
#	print Dumper($self);
	$id_field = ((defined $opts{idField}) && ($opts{idField} ne '0') && ($opts{idField} ne '')) ? $opts{idField} : 'id';

	# Генерим сам запрос с данными
	foreach (sort keys %{$self->{fieldsTable}}) {
		$_ =~ s/^\d+_//;
		if (defined $self->{"$_"} && $self->{"$_"} ne '') {
			if ($_ ne $id_field) {
				push @placeHolder, "`$_` = ?";
				push @fildsData, $self->{"$_"};
			} else {
				$whereID = $self->{"$_"};
			}
		}
	}

	# Валидации на наявность всех данных
	if(!@fildsData){
		$self->_handle_error("Array data table $self->{table} empty!");
	}

	if (!defined $opts{idField} || (defined $opts{idField}) && ($opts{idField} ne False)) {
		# Определяем поле по которому будим апдейтить
		$condition = "WHERE `$id_field` = ".$self->{DBH}->quote($whereID);
	}


#	if(!$whereID){
#		$self->_handle_error("ID table $self->{table} not found!")
#	}

	# Тут все понятно :)
	$strPlaceHolder = join(', ', @placeHolder);
#print "UPDATE `$self->{table}` SET $strPlaceHolder $condition\n";
	# Исполняем запрос
	eval {
		$sth = $self->{DBH}->prepare("UPDATE `$self->{table}` SET $strPlaceHolder $condition\n");
		$rows = $sth->execute(@fildsData);
	} or $self->_handle_error($self->{DBH}->errstr());

	((! defined $rows) || ($rows eq '0E0')) ? return 0 : return 1;
}





=cut

 sub new_employee {
	# Arguments: database handle; first and last names of new employee;
	# department ID number for new employee's work assignment
	my ($dbh, $first, $last, $department) = @_;
	my ($insert_handle, $update_handle);
	my $insert_handle = $dbh->prepare_cached('INSERT INTO employees VALUES (?,?,?)'); 
	my $update_handle = $dbh->prepare_cached('UPDATE departments 
																SET num_members = num_members + 1
																WHERE id = ?');
	die "Couldn't prepare queries; aborting" unless defined $insert_handle && defined $update_handle;
	my $success = 1;

	$success &&= $insert_handle->execute($first, $last, $department);
	$success &&= $update_handle->execute($department);

	my $result = ($success ? $dbh->commit : $dbh->rollback);

	unless ($result) { 
		die "Couldn't finish transaction: " . $dbh->errstr 
	}

	return $success;
}



 eval {
      foo(...)        # do lots of work here
      bar(...)        # including inserts
      baz(...)        # and updates
      $dbh->commit;   # commit the changes if we get this far
  };
  if ($@) {
      warn "Transaction aborted because $@";
      # now rollback to undo the incomplete changes
      # but do it in an eval{} as it may also fail
      eval { $dbh->rollback };
      # add other application on-error-clean-up code here
  }






### Connect to the database with transactions and error handing enabled
my $dbh = DBI->connect( "dbi:Oracle:archaeo", "username", "password" , {
    AutoCommit => 0,
    RaiseError => 1,
} );

### Keep a count of failures. Used for program exit status
my @failed;

foreach my $country_code ( qw(US CA GB IE FR) ) {

    print "Processing $country_code\n";

    ### Do all the work for one country inside an eval
    eval {

        ### Read, parse and sanity check the data file (e.g., using DBD::CSV)
        my $data = load_sales_data_file( "$country_file.csv" );

        ### Add data from the Web (e.g., using the LWP modules)
        add_exchange_rates( $data, $country_code,
                            "http://exchange-rate-service.com" );

        ### Perform database loading steps (e.g., using DBD::Oracle)
        insert_sales_data( $dbh, $data );
        update_country_summary_data( $dbh, $data );
        insert_processed_files( $dbh, $country_code );

        ### Everything done okay for this file, so commit the database changes
        $dbh->commit();

    };

    ### If something went wrong...
    if ($@) {

        ### Tell the user that something went wrong, and what went wrong
        warn "Unable to process $country_code: $@\n";
        ### Undo any database changes made before the error occured
        $dbh->rollback();

        ### Keep track of failures
        push @failed, $country_code;

    }
}
$dbh->disconnect();

### Exit with useful status value for caller
exit @failed ? 1 : 0;

=cut



sub getResult() {
	($self, %opts) = @_;
	return $self->{Result};
}

# составление запроса к базе данных
sub _getSelect() {
	($self, my %proviso) = @_;
	my $querySql;

	if (scalar(keys %proviso) > 0) {
		foreach (keys %proviso){
			$proviso{uc($_)} = $proviso{$_};
			delete $proviso{$_};
		}

		if(exists $proviso{"WHERE"}){
			$querySql .= " WHERE " . $proviso{"WHERE"};
		}

		if(exists $proviso{"GROUP"}){
			$querySql .= " GROUP BY " . $proviso{"GROUP"};
		}

		if(exists $proviso{"ORDER"}){
			$querySql .= " ORDER BY " . $proviso{"ORDER"};
		}

		if(exists $proviso{"LIMIT"}){
			$querySql .= " LIMIT " . $proviso{"LIMIT"};
		}
		return $querySql;
	}		
}

# выполнение запроса к базе данных
sub _getResult(){
	($self, @args) = @_;
	my $sql = shift(@args);
	$sth = $self->{DBH}->prepare("$sql");
	$sth->execute ();
	$self->{dataResult} = \@{$sth->fetchall_arrayref()};
	return @{$self->{dataResult}};
}

# выполнение запроса к базе данных
sub _getQuery(){
	($self, %opts) = @_;
	# обработка запроса, если нужно
	#my $sql = $self->_getSelect($this->proviso);
	my $sql = $self->_getSelect(%opts);
	$self->_getResult("SELECT * FROM $self->{table}".$sql);
}

sub _getTableStructure() {
	($self, @args) = @_;
	undef $self->{fieldsTable};
	my $rows;
	### The SQL statement to fetch the table metadata   
	### Prepare and execute the SQL statement
	eval {
		$sth = $self->{DBH}->prepare( "SELECT * FROM $self->{table} WHERE 1=0" );
		$rows = $sth->execute();
	} or $self->_handle_error($self->{DBH}->errstr());

	### Iterate through all the fields and dump the field information
	if ($rows){
		for ( my $i = 0; $i < $sth->{NUM_OF_FIELDS}; $i++ ) {
			my $name = $sth->{NAME}->[$i];
			my $prec  = $sth->{PRECISION}->[$i];
			my $type  = $sth->{TYPE}->[$i];
			$type = $self->{DBH}->type_info($type)->{TYPE_NAME};
			### Colect the field information
	
			$self->{fieldsTable}->{$i."_".$name} = {	Type => uc($type),
														Precision => $prec
													};
		}

		### Explicitly deallocate the statement resources
		### because we didn't fetch all the data
		$sth->finish();
		return True;
	} else {
		return False;
	}
}

# получить количество записей
sub rows(){
	($self, @args) = @_;
	return $sth->rows;
}

sub setAutoCommit() {
	($self, my $args) = @_;
	if ($args =~ /on|yes|true|1/i) {
		$self->{DBH}->{AutoCommit} = 1;
	} else {
		$self->{DBH}->{AutoCommit} = 0;
	}
}

sub commit() {
	($self, my $args) = @_;
	return $self->{DBH}->commit();
}

sub rollback() {
	($self, my $args) = @_;
	return $self->{DBH}->rollback();
}

sub Finish() {
	#$sth->finish();
	$self->{DBH}->disconnect;
};

sub _handle_error {
	($self, my $message) = @_;
#	$message = $self->{DBH}->errstr();
	print "The Error message is '$message'\n";
	#exit;
}

END {
}


1;