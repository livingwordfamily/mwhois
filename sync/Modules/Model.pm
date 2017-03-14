package Model;

use strict;
use warnings;
use Exporter qw(import);
use Data::Dumper;
use Utils qw/INET_NTOA INET_ATON ConvMask trim/;
use base qw/DB/;

my %opts;
my @args;
my $class;
my $self;
my $sql;

BEGIN { }

sub New() {
	($class, %opts) = @_;
	$self = DB::New(	$class,
						DBH => $opts{DBH_IPPLAN},
						%opts
					);
	return $self;
}

sub getRegionList() {
	($self, %opts) = @_;
	my ( @regionList, $regionList, @regionLoopbacks, $loopbackData, $rangeindex, $baseindex);
	my ($regionSubNet, $intRegionSubNet, $regionID, $intIP, $regionSubNetSize, $intRegionSubNetSize, $descrip);
	my ($ip, $whLocation, $certName, $code1C, $lastmod, $areaindex, $customer, @whNets, @whPersonalData);
	my %regionData;
	$self->{DBH} = $self->{DBH_IPPLAN}; # Переключаем ДБ хендл на другую БД (IPPLAN "ipplan.np.ua")

	### Получаем список регионов и их подсеть
	$sql = "	SELECT
						INET_NTOA(`rangeaddr`),
						`rangeaddr`,
						`rangesize`,
						`descrip`,
						`areaindex`,
						`customer`
				FROM	`netrange`
				WHERE	`descrip` LIKE 'REG:%' AND NOT
						`descrip` LIKE '%Reserved%' AND NOT
						`descrip` LIKE '%REGIONAL%'
				ORDER BY `rangeaddr`";

	@regionList = $self->rawQuery("$sql");



	foreach $regionList (@regionList) {
		($regionSubNet, $intRegionSubNet, $intRegionSubNetSize, $descrip, $areaindex, $customer) = @{$regionList};

		$sql = "	SELECT
							`rangeindex`
					FROM
							`netrange`
					WHERE
							`rangeaddr` = ?
						AND
							`areaindex` = ?
						AND
							`customer` = ?";

		$self->{DBH} = $self->{DBH_IPPLAN}; # Переключаем ДБ хендл на другую БД (IPPLAN "ipplan.np.ua")
		($rangeindex) = ($self->rawQuery("$sql", $intRegionSubNet, $areaindex, $customer))[0][0];

		$regionID = ($regionSubNet =~ /\d+\.(\d+)\.0\.0/)[0];
		$regionSubNetSize = ConvMask(
									Action => 'STOC',
									Value => $intRegionSubNetSize
								);

		$regionData{$regionSubNet} = {
										Network => $regionSubNet,
										Broadcast => INET_NTOA($intRegionSubNet + $intRegionSubNetSize - 1),
										RegionCIDR => "$regionSubNet/$regionSubNetSize",
										FileName => "$regionSubNet-$regionSubNetSize",
										RegionID => $regionID,
										Descrip => $descrip,
										Lastmod => $lastmod,
										AreaIndex => $areaindex,
										Customer => $customer,
										RangeIndex => $rangeindex
									};

		$sql = "	SELECT	INET_NTOA(`ipaddr`),
							`location`,
							`userinf`,
							`telno`,
							`baseindex`,
							`lastmod`
					FROM `ipaddr`
					WHERE `ipaddr` BETWEEN ? AND ?
					ORDER BY `ipaddr` DESC";
		@regionLoopbacks = $self->rawQuery("$sql", INET_ATON("10.$regionID.248.0"), (INET_ATON("10.$regionID.248.0") + 2048));
		foreach $loopbackData (@regionLoopbacks) {
			($ip, $whLocation, $certName, $code1C, $baseindex, $lastmod) = @{$loopbackData};
			
			$sql = "	SELECT 	INET_NTOA(t1.`baseaddr`),
								INET_NTOA(t1.`baseaddr`+t1.`subnetsize`-2),
								`descrip`,
								t1.`subnetsize`,
								t1.`baseindex`,
								`lastmod`
						FROM	`ipplan`.`base` as t1,
							(
								SELECT	`baseindex` FROM  
										`ipplan`.`ipaddr`
								WHERE
										`ipaddr` BETWEEN '182452224' AND '184549375' AND
										`userinf` LIKE concat('LNK', ?)
							) as t2
						WHERE t1.`baseindex` = t2.`baseindex`";

			$self->{DBH} = $self->{DBH_IPPLAN}; # Переключаем ДБ хендл на другую БД (IPPLAN "ipplan.np.ua")
			@whNets = $self->rawQuery("$sql", $ip);

			$self->{DBH} = $self->{DBH_IPNP}; # Переключаем ДБ хендл на другую БД (IPPLAN "ipplan.np.ua")
			$self->{DBH}->do('use ipnp');
			$sql = "
					SELECT
							`Warehouse_Name` AS WarehouseName,
							`Warehouse_Address` AS WarehouseAddress,
							`Chief_name` AS ChiefName,
							`Status`,
							`int_phone` AS IntPhone,
							`number` AS Number,
							`latitude` AS Latitude,
							`longitude` AS Longitude,
							`Wh_phone` AS WhPhone,
							`Wh_type` AS WhType
					FROM
							`warehouse`
					WHERE `Warehouse_Code` = ?
					LIMIT 1	";

			@whPersonalData = $self->rawQuery("$sql", $code1C,);

			$regionData{$regionSubNet}{WareHouseList}{$ip} = {	
																IP => $ip,
																FileName => "$ip-32",
																WHLocation => $whLocation,
																CertName => $certName,
																Code1C => $code1C,
																BaseIndex => $baseindex,
																LastMod => $lastmod,
																WarehouseName => $whPersonalData[0][0],
																WarehouseAddress => $whPersonalData[0][1],
																ChiefName => $whPersonalData[0][2],
																Status => $whPersonalData[0][3],
																IntPhone => $whPersonalData[0][4],
																Number => $whPersonalData[0][5],
																Latitude => $whPersonalData[0][6],
																Longitude => $whPersonalData[0][7],
																WhPhone => $whPersonalData[0][8],
																WhType => $whPersonalData[0][9],
																WhNets => [@whNets]
															};
			#print "$ip => $whLocation => ";
			#print Dumper @whNets;
		}

#		print Dumper @regionLoopbacks;
	}
#	print Dumper %regionData;
	#@regionList = $self->rawQuery("$sql");	
	return %regionData;
}


=cut


	



	$sql = "	SELECT 	INET_NTOA(t1.`baseaddr`),
						INET_NTOA(t1.`baseaddr`+1),
						INET_NTOA(t1.`baseaddr`+2),
						INET_NTOA(t1.`baseaddr`+t1.`subnetsize`-2),
						t1.`subnetsize`						
				FROM	`ipplan`.`base` as t1,
					(
						SELECT	`baseindex` FROM  
								`ipplan`.`ipaddr`
						WHERE
								`ipaddr` BETWEEN '182452224' AND '184549375' AND
								`userinf` LIKE concat('LNK', ?)
					) as t2
				WHERE t1.`baseindex` = t2.`baseindex`";


if (scalar @_ eq 1) {
		$maskInCidr = ConvMask(
							Action => "size_to_cidr",
							Value => $_[0][4]
						);
		$self->{RegionData}{LanIp} = "$_[0][1]";
		$self->{RegionData}{LanNet} = "$_[0][0]";
		$self->{RegionData}{Subnet} = "$maskInCidr";
		$self->{RegionData}{DHCPEnd} = "$_[0][3]";
		$self->{RegionData}{DHCPStart} = "$_[0][2]";

		return True;
	} elsif (scalar @_ gt 1) {
		$self->{Error} = "wh_net_err_mesg";
		return False;
	} else {
		$self->{Error} = "linked_ad_err_mesg";
		return False;
	}


	sub getNumberWh() {
	($self, my $id_1c) = @_;
	my ($numberWh, @numberWh_ref);

	$self->{DBH} = $self->{DBH_IPNP}; # Переключаем ДБ хендл на другую БД (IPNP "us.np.ua")
	$self->{DBH}->do('use ipnp');

	$sql = "	SELECT	
						`num`
				FROM `adress_1c`
				WHERE `id` = ?";

	@numberWh_ref = $self->rawQuery("$sql", $id_1c);
	
	$numberWh = (@numberWh_ref) ? $numberWh_ref[0][0] : 0;

	return $numberWh;
}
=cut
END {};

1;