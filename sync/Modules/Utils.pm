package Utils;	# Такое же как и имя этого файла без расширения '.pm'
use strict;
use Exporter qw(import); # Обязательная строка для экспорта имен
use warnings;
use Data::Dumper;
use constant {
		#PI => (4 * atan2 1, 1),
		True => 1,
		False => 0
	};

use Net::Ping::External qw/ping/;

our @ISA         = qw(Exporter); # -//-
our $VERSION     = 2.00;

our @EXPORT = qw( True False );
our @EXPORT_OK   = qw(&GenToken &GenNewID &trim &apostrov &DateTime &ConvTime &GenClientID &decode_utf &INET_ATON &INET_NTOA &ConvMask &ceil &floor &CheckHost True False &JSONToHash &BitToString &CidrToNumber &quote &HostValidation);
our %EXPORT_TAGS = ( DEFAULT => [qw(&init &new)] );

#@EXPORT = qw(&main &SearchCert) # Перечисляем имена функций. Внимание ! нет запятой!
#@EXPORT_OK = qw( $переменная @массив ); # Указать публичные переменные, массивы
#                                и т.д. если необходимо
#package Sample;
#require Exporter;              # загружаем модуль Exporter
#@ISA = qw(Exporter);           # указываем, что неизвестные имена нужно искать в нем
                               # и определяем:
#@EXPORT = qw(...);             # символы, экспортируемые по умолчанию
#@EXPORT_OK = qw(...);          # символы, экспортируемые по запросу
#%EXPORT_TAGS = (tag => [...]); # имена для наборов символов

my $class;
my %opts;
my (@args, $arg);
my (%keys, $value);
my $self;
my $token;
my @rnd_txt;
my %mask;

my @RawData;
my @LineRawData;
my $ref;
my %Data;
my $key;

# print scalar getpwuid($<)."\n"; Carent user
BEGIN {};

sub floor
{
	die "floor: an argument expected\n"
		if @_ != 1;

	my $num = shift;
	if ($num == int($num)) {
		$num;
	} else {
		$num = int($num);
		$num -= ($num >= 0) ? 0 : 1;
	}
}
 
sub ceil
{
	die "ceil: an argument expected\n"
		if @_ != 1;

	my $num = shift;
	if ($num == int($num)) {
		$num;
	} else {
		$num = floor($num) + 1;
	}
}

sub ConvTime {
	my @day = ("Mon","Tew","Thu","Wen","Fri", "Sat","Sun");
	my @months = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Avg","Sen","Oct","Nov","Dec");
	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime($_[0]);
	return sprintf "%s, %02d %s %4d %02d:%02d:%02d", $day[$wday - 1], $mday, $months[$mon], $year + 1900, $hour, $min, $sec;
}

sub DateTime {
	my @day = ("Mon","Tew","Thu","Wen","Fri", "Sat","Sun");
	my @months = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Avg","Sen","Oct","Nov","Dec");
	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
	#return sprintf "%s, %02d %s %4d %02d:%02d:%02d", $day[$wday - 1], $mday, $months[$mon], $year + 1900, $hour, $min, $sec;
	return sprintf "%02d-%02d-%4d", $mday, $mon+1, $year + 1900;
}

sub ExcelTimeStamp {
#perl -MPOSIX -ple's/^\d{5}/strftime("%a %m\/%d\/%Y",gmtime(86400*($&-25569)))/e'
}

sub sec2human {
    my $secs = shift;
    if    ($secs >= 365*24*60*60) { return sprintf '%.1fy', $secs/(365*24*60*60)}	#year
    elsif ($secs >=     24*60*60) { return sprintf '%.1fd', $secs/(24*60*60) 	}	#days
    elsif ($secs >=        60*60) { return sprintf '%.1fh', $secs/(60*60) 		}	#hours
    elsif ($secs >=           60) { return sprintf '%.1fm', $secs/(60)			}	#min
    else                          { return sprintf '%.1fs', $secs				}	#sec

#	my $hrs = int( $sec / (60*60) );
#	my $min = int( ($sec - $hrs*60*60) / (60) );
#	my $sec = int( $sec - ($hrs*60*60) - ($min*60) );
}

#sub deg2rad { PI * $_[0] / 180 }

sub trim {
	$_[0] =~ s/^\s+|\s+$//gi if $_[0];
	$_[0] =~ s/^\n+|\n+$//gi if $_[0];
	$_[0] =~ s/^\r+|\r+$//gi if $_[0];
	$_[0] =~ s/\\u200b$//gi if ($_[0]);
	return $_[0];
};

sub quote() {

print $_[0];
#				0    1    2     3    4     5     6     7      8     9     10
my @string = ('\x1a', '\\\\', '\%', '\_');
my @regex = ('\\Z', '\\\\', '\%', '\\_');
my $i = 0;
my $string;
my $value = $_[0];

for $string (@string) {
	$value =~ s/$string/$regex[$i]/g;
	$i++;
}
$value =~ s/\t/\\t'/g;
$value =~ s/\r/\\r/g;
$value =~ s/\n/\\n/g;
#$value =~ s/0/\\0/g;
$value =~ s/\'/\\'/g;
$value =~ s/\"/\\"/g;
return "'$value'";	

#    //MySQL escape sequences: http://dev.mysql.com/doc/refman/5.1/en/string-syntax.html
#    String[][] search_regex_replacement = new String[][]
#    {
#                //search string     search regex        sql replacement regex
#            {   "\u0000"    ,       "\\x00"     ,       "\\\\0"     },
#            {   "'"         ,       "'"         ,       "\\\\'"     },
#            {   "\""        ,       "\""        ,       "\\\\\""    },
#            {   "\b"        ,       "\\x08"     ,       "\\\\b"     },
#            {   "\n"        ,       "\\n"       ,       "\\\\n"     },
#            {   "\r"        ,       "\\r"       ,       "\\\\r"     },
#            {   "\t"        ,       "\\t"       ,       "\\\\t"     },
#            {   "\u001A"    ,       "\\x1A"     ,       "\\\\Z"     },
#            {   "\\"        ,       "\\\\"      ,       "\\\\\\\\"  }
#    };

#Table 10.1 Special Character Escape Sequences

#Escape Sequence	Character Represented by Sequence
#\0	An ASCII NUL (X'00') character
#\'	A single quote (“'”) character
#\"	A double quote (“"”) character
#\b	A backspace character
#\n	A newline (linefeed) character
#\r	A carriage return character
#\t	A tab character
#\Z	ASCII 26 (Control+Z); see note following the table
#\\	A backslash (“\”) character
#\%	A “%” character; see note following the table
#\_	A “_” character; see note following the table
	return "'$_'";
}

sub INET_ATON{ 
	return unpack("N",pack("C4",split(/\./,"$_[0]"))); 
};

sub INET_NTOA { 
	return (($_[0]>>24) & 255) .".". (($_[0]>>16) & 255) .".". (($_[0]>>8) & 255) .".". ($_[0] & 255); 
};

sub netmask2cidr {
	my @octet = split (/\./, $_[0]);
	my @bits;
	my $binmask;
	my $binoct;
	my $cidr=0;

	foreach (@octet) {
		$binoct = unpack("B32", pack("N", $_));
		$binmask = $binmask . substr $binoct, -8;
	}

	@bits = split (//,$binmask);
	foreach (@bits) {
		if ($_ eq "1") {
			$cidr++;
		}
	}
	return $cidr;
}

sub CidrToNumber {
	return ( 2 ** (32 - $_[0]) ) if $_[0];
}

sub CheckHost {
	#if (ping(host=>$_[0], count => 2, ttl => 1)) {
	if ($_[0] && ping(host=>$_[0], count => 1)) {
		print ping(host=>$_[0], count => 1);
		return 1;
	} else {
		return 0;
	}
};

sub HostValidation() {
	my %opts = @_;
	my %result;

	$opts{Count} = $opts{Count} || 3;
	$opts{Interval} = $opts{Interval} || 1;
	$opts{Size} = (defined $opts{Size} && $opts{Size} ne '') ? ($opts{Size} - 8) : 56;
	$opts{Fragment} = (defined $opts{Fragment} && $opts{Fragment} == True) ? '' : '-Mdo';

	my $res = `ping -q -c$opts{Count} -i$opts{Interval} $opts{Fragment} $opts{Host}`;

	if ($res =~ /errors/m) {
		($result{rcv}, $result{err}, $result{perc}, $result{time}) = ($res =~ /^\d+\s+packets transmitted,\s+(\d+)\s+\w+,\s+\+(\d+)\s+\w+,\s(\d+).*?time\s(\d+)ms$/m);
	} else {
		($result{rcv}, $result{perc}, $result{time}) = ($res =~ /^\d+\s+packets transmitted,\s+(\d+)\s+\w+,\s+(\d+).*?(\d+)ms$/m);
		($result{min}, $result{avg}, $result{max}, $result{mdev}) = ($res =~ /^.*?min\/avg\/max\/mdev.*?([\d\.]+)\/([\d\.]+)\/([\d\.]+)\/([\d\.]+).*$/m);
	}
	
	return %result;
}


# valid_ip возвращает тескт ошибки либо 0 в случае валидности IP
sub valid_ip {
	my $cheked_ip = shift;
	return "Не указан IP" unless ( $cheked_ip );
	return "Недопустимые символы в IP $cheked_ip" unless ( $cheked_ip =~ m/^[\d\.]+$/ );
	return "Недопустимый IP $cheked_ip - начинается с точки" if ($cheked_ip =~ m/^\./);
	return "Недопустимый IP $cheked_ip - заканчивается точкой" if ($cheked_ip =~ m/\.$/);
	# Число октетов
	return "Ошибка - IP адрес должен содержать 4 октета" unless ( 3 == ($cheked_ip =~ tr/\./\./) );
	# Проверка пустых октетов
	return "Не указана часть IP - две точки подряд" if ($cheked_ip =~ m/\.\./);
	# Проверка на допустимый диапазон значений в октете
	foreach (split /\./, $cheked_ip) {
		return "Недопустимое значение в IP адресе $cheked_ip - $_" unless ($_ >= 0 && $_ < 256 && $_ !~ /^0\d{1,2}$/ );
	}
	return 0;
}

################################################################################
# Процедура создания token
################################################################################

sub GenToken {
	%opts = @_;
	my (@digit, @alphabetUpper, @alphabetLower);
	undef $token;
	$opts{TokenLength} = (defined $opts{TokenLength}) ? $opts{TokenLength} : 8;

	# Массив символов для token
	@digit = (	'0','1','2','3','4','5','6','7','8','9');

	@alphabetLower = (
					'a','b','c','d','e','f','g','h','i','j','k','l',
					'm','n','o','p','r','s','t','u','v','w','x','y','z');

	@alphabetUpper = map{uc $_} @alphabetLower;
	
	push(@rnd_txt, @alphabetLower) if !(defined $opts{AlphabetLower} && ($opts{AlphabetLower}  =~ /no|false/i));
	push(@rnd_txt, @alphabetUpper) if !(defined $opts{AlphabetUpper} && ($opts{AlphabetUpper}  =~ /no|false/i));
	push(@rnd_txt, @digit) if !(defined $opts{Digit} && ($opts{Digit}  =~ /no|false/i));

	srand;
	# Генерим token
	for (1..$opts{TokenLength}) {
		$token .= $rnd_txt[rand(@rnd_txt)]
	};
	return $token;
};

sub JSONToHash {
	undef %Data;
	undef @RawData;
	undef @LineRawData;
	#if ($_[0] =~ /},{/) {


#{"10.239.200.100:44972":{"SerialNumber":"279501A235F6","MAC":"ether1:00:0C:42:7F:6D:41,ether2:00:0C:42:7F:6D:42,ether5:00:0C:42:7F:6D:45,ether3:00:0C:42:7F:6D:43,ether4:00:0C:42:7F:6D:44","IPLocal":"10.239.200.126","BadBlocks":"2.6%","ROSVersion":"6.27","BoardName":"RB450","time":"1437132800"}}


		if ($_[0] =~ /:(\s+)?{/) {

			print "Hash JSOM\n";
			} else {
				#print "NONE Hash JSON\n";
	#@RawData = split(/},{/, $_[0]);
	#	}
#	my $qq = shift;
#		print "sfdgs  df = >@_\n\n\n";
		@RawData = @_;
	foreach (@RawData){
		$_ =~ s/^{|}$//gi;
		$_ =~ s/^"|"$//gi;
		#print "$_\n";
		@LineRawData = split(/",.*?"/, &decode_utf($_));
		#($key, $ref)= split(/":/,shift @LineRawData);
		foreach (@LineRawData){

			($key, $value) = split(/":"/,$_);
			#$value = &remStuff($value);
		#	print "$key => $value\n";

			$Data{$key} = $value;

#			if ($key eq 'IsFolder' && $value) {
#				print "$ref	- IsFolder - OK\n";
				#print Dumper($FizOsobaData{$ref});
				
#				&FizOsoba_folders("$ref");
#			} elsif ($key eq 'IsFolder') {
#				print "$ref	- IsFolder - NOT - OK !!!!!!!!!!!!\n";
				#print Dumper($FizOsobaData{$ref});
#			}
		}
#		return \%Data if ($i >= 10);
		#$i++;
		#print "$i - $start\n";
	}
}
#}
#	print Dumper(%Data);
#sleep 3;
	return %Data;
}
sub JSONParser_hash {
	@RawData = split(/},\{/, $_[0]);
	foreach (@RawData){
		$_ =~ s/^"|"$//gi;
		@LineRawData = split(/,"/, &decode_utf($_));
		($key, $ref)= split(/":/,shift @LineRawData);
		foreach (@LineRawData){

			($key, $value) = split(/":/,$_);
			#$value = &remStuff($value);
#			print "$key => $value\n";
			$Data{&remStuff($ref)}->{$key} = &remStuff($value);
#			if ($key eq 'IsFolder' && $value) {
#				print "$ref	- IsFolder - OK\n";
				#print Dumper($FizOsobaData{$ref});
				
#				&FizOsoba_folders("$ref");
#			} elsif ($key eq 'IsFolder') {
#				print "$ref	- IsFolder - NOT - OK !!!!!!!!!!!!\n";
				#print Dumper($FizOsobaData{$ref});
#			}
		}
#		return \%Data if ($i >= 10);
		#$i++;
		#print "$i - $start\n";
	}
	print Dumper(%Data);
	return \%Data;
}

sub BitToString {
 my %opts = @_;
 my $exten = '';
 my $short;
 if ($opts{Value} < 1000) {
  $exten = $opts{LangHash}{bit};
  $short = $opts{Value};
 } elsif($opts{Value} < (1000000)) {
  $exten = $opts{LangHash}{kbit};
  $short = $opts{Value}/1000;
 } elsif ($opts{Value} < (1000000000)) {
  $exten = $opts{LangHash}{Mbit};
  $short = $opts{Value}/1000000;
 } elsif ($opts{Value} < (1000000000000)) {
  $exten = $opts{LangHash}{Gbit};
  $short = $opts{Value}/1000000000;
 } elsif ($opts{Value} < (1000000000000000)) {
  $exten = $opts{LangHash}{Tbit};
  $short = $opts{Value}/1000000000000;
 } elsif ($opts{Value} < (1000000000000000000)) {
  $exten = $opts{LangHash}{Pbit};
  $short = $opts{Value}/1000000000000000;
 } elsif ($opts{Value} < (1000000000000000000000)) {
  $exten = $opts{LangHash}{Ebit};
  $short = $opts{Value}/1000000000000000000;
 } elsif ($opts{Value} < (1000000000000000000000000)) {
  $exten = $opts{LangHash}{Zbit};
  $short = $opts{Value}/1000000000000000000000;
 } elsif ($opts{Value} < (1000000000000000000000000000)) {
  $exten = $opts{LangHash}{Ybit};
  $short = $opts{Value}/1000000000000000000000000;
 } else {
  $exten = $opts{LangHash}{Ybit};
  $short = $opts{Value}/1000000000000000000000000;
 }

 if (int($short) == $short) {
  return "$short $exten";
 } else {
  return sprintf("%.2f ".$exten, $short);
 }
}

sub decode_utf {
	my %map = (
				U0410 => 'А',	U0430 => 'а',
				U0411 => 'Б',	U0431 => 'б',
				U0412 => 'В',	U0432 => 'в',
				U0413 => 'Г',	U0433 => 'г',
				U0414 => 'Д',	U0434 => 'д',
				U0415 => 'Е',	U0435 => 'е',
				U0401 => 'Ё',	U0451 => 'ё',
				U0416 => 'Ж',	U0436 => 'ж',
				U0417 => 'З',	U0437 => 'з',
				U0418 => 'И',	U0438 => 'и',
				U0419 => 'Й',	U0439 => 'й',
				U041A => 'К',	U043A => 'к',
				U041B => 'Л',	U043B => 'л',
				U041C => 'М',	U043C => 'м',
				U041D => 'Н',	U043D => 'н',
				U041E => 'О',	U043E => 'о',
				U041F => 'П',	U043F => 'п',
				U0420 => 'Р',	U0440 => 'р',
				U0421 => 'С',	U0441 => 'с',
				U0422 => 'Т',	U0442 => 'т',
				U0423 => 'У',	U0443 => 'у',
				U0424 => 'Ф',	U0444 => 'ф',
				U0425 => 'Х',	U0445 => 'х',
				U0426 => 'Ц',	U0446 => 'ц',
				U0427 => 'Ч',	U0447 => 'ч',
				U0428 => 'Ш',	U0448 => 'ш',
				U0429 => 'Щ',	U0449 => 'щ',
				U042A => 'Ъ',	U044A => 'ъ',
				U042B => 'Ы',	U044B => 'ы',
				U042C => 'Ь',	U044C => 'ь',
				U042D => 'Э',	U044D => 'э',
				U042E => 'Ю',	U044E => 'ю',
				U042F => 'Я',	U044F => 'я',
				U0406 => 'І',	U0456 => 'і',	
				U0457 => 'ї',	U0407 => 'Ї',
				U0454 => 'є',	U0404 => 'Є',
				U0490 => 'Ґ',	U0491 => 'ґ',
				U2116 => '№'
			);

	while(($key,$value) = each %map){
		$_[0] =~ s/\\U(\d+)/U$1/gi;
		$_[0] =~ s/$key/$value/gi;
	};

	return $_[0];
}

sub ConvMask {
	%opts = @_;

	%mask =( 	
			1 => {
					cidr => '32',
					netmask => '255.255.255.255'
				},
			2 => {
					cidr => '31',
					netmask => '255.255.255.254'
				},
			4 => {
					cidr => '30',
					netmask => '255.255.255.252'
				},
			8 => {
					cidr => '29',
					netmask => '255.255.255.248'
				},
			16 => {
					cidr => '28',
					netmask => '255.255.255.240'
				},
			32 => {
					cidr => '27',
					netmask => '255.255.255.224'
				},
			64 => {
					cidr => '26',
					netmask => '255.255.255.192'
				},
			128 => {
					cidr => '25',
					netmask => '255.255.255.128'
				},
			256 => {
					cidr => '24',
					netmask => '255.255.255.0'
				},
			512 => {
					cidr => '23',
					netmask => '255.255.254.0'
				},
			1024 => {
					cidr => '22',
					netmask => '255.255.252.0'
				},
			2048 => {
					cidr => '21',
					netmask => '255.255.248.0'
				},
			4096 => {
					cidr => '20',
					netmask => '255.255.240.0'
				},
			8192 => {
					cidr => '19',
					netmask => '255.255.224.0'
				},
			16384 => {
					cidr => '18',
					netmask => '255.255.192.0'
				},
			32768 => {
					cidr => '17',
					netmask => '255.255.128.0'
				},
			65536 => {
					cidr => '16',
					netmask => '255.255.0.0'
				},
			131072 => {
					cidr => '15',
					netmask => '255.254.0.0'
				},
			262144 => {
					cidr => '14',
					netmask => '255.252.0.0'
				},
			524288 => {
					cidr => '13',
					netmask => '255.248.0.0'
				},
			1048576 => {
					cidr => '12',
					netmask => '255.240.0.0'
				},
			2097152 => {
					cidr => '11',
					netmask => '255.224.0.0'
				},
			4194304 => {
					cidr => '10',
					netmask => '255.192.0.0'
				},
			8388608 => {
					cidr => '9',
					netmask => '255.128.0.0'
				},
			16777216 => {
					cidr => '8',
					netmask => '255.0.0.0'
				},
			33554432 => {
					cidr => '7',
					netmask => '254.0.0.0'
				},
			67108864 => {
					cidr => '6',
					netmask => '252.0.0.0'
				},
			134217728 => {
					cidr => '5',
					netmask => '248.0.0.0'
				},
			268435456 => {
					cidr => '4',
					netmask => '240.0.0.0'
				},
			536870912 => {
					cidr => '3',
					netmask => '224.0.0.0'
				},
			1073741824 => {
					cidr => '2',
					netmask => '192.0.0.0'
				},
			2147483646 => {
					cidr => '1',
					netmask => '128.0.0.0'
				},
			4294967296 => {
					cidr => '0',
					netmask => '0.0.0.0'
				}
	);

	if ($opts{Action} eq "size_to_cidr" || $opts{Action} eq 'STOC') {
		return $mask{$opts{Value}}{cidr};
	} elsif ($opts{Action} eq "cidr_to_size" || $opts{Action} eq 'CTOS') {
		for (keys %mask) {
			return $_ if ($mask{$_}{cidr} == $opts{Value});
		}
	}
}

################################################################################
# Процедура генерирования цифровых ID
################################################################################

sub ClientIDCheck {
	my $sql_query="	SELECT	`id_client_login`
					FROM	`client_logins`
					WHERE	`id_client_login` = '$_[1]'";
	print Dumper($_[0]);
	my $query = $_[0] -> prepare($sql_query);
#	my $query = $_[0]->Query($sql_query);
	#$query -> execute ();
	$query = $_[0]->execute($query);
	$query = $_[0]->rows($query);
	#return $query -> rows();
	print Dumper($query);
};

sub GenNewID {
	my $gen_id;
	undef $gen_id;
	for( my $i = 0; $i < $_[0]; $i++ ){
		$gen_id .= int(rand(10));
	};
	return $gen_id;
};

sub GenClientID {
	my %opts = @_;
		my $new_id = &GenNewID($opts{IDLength});
		if (!ClientIDCheck($opts{SQL}, $new_id)){return $new_id;};
	return $new_id;
};


sub CidrToNetmask {
	return join(".", unpack("C4",pack("N", ((2**$_[0]-1) << (32-$_[0])) )));
};

END {};

1;