package Core;

use strict;
use warnings;
use Data::Dumper;
use Utils qw/trim ConvMask/; # True False CheckHost
#use localisation qw/Translit/;

my (%opts, @args, %data);
my ($self, $class);

BEGIN { }

sub New {
	($class, %opts) = @_;
	$self = bless({%opts}, $class);
	return $self;
}

sub createDB() {
	($self, %opts) = @_;
	print Dumper %opts;
	my ( $region, $wareHause);
	unlink glob "./../db/ipv4/*";
	my %ee;
	my $whNets;
	foreach $region (keys %opts){
		
		$self->genWhoisDB(%{$opts{$region}});
		foreach $wareHause (keys %{$opts{$region}{WareHouseList}}){
			%ee = (%{$opts{$region}}, %{$opts{$region}{WareHouseList}{$wareHause}});
			foreach $whNets (@{$opts{$region}{WareHouseList}{$wareHause}{WhNets}}) {
				$ee{WhNetwork} = $$whNets[0];
				$ee{WhBroadcast} = $$whNets[1];
				$ee{WhCIDR} = "$$whNets[0]/".ConvMask(
														Action => 'STOC',
														Value => $$whNets[3]
														);
				$ee{WhDescrip} = $$whNets[2];
			}
#			print "$wareHause\n";
			$self->genWhoisDB(%ee);
		}
	}
	
}


#################################################################
################ Генерация конфигурации из темплейта ############
#################################################################

sub genWhoisDB {
	($self, %data) = @_;
	my (@keys, $key, $keyValue);
	open(Template, "./Template/network.tmpl") || die "Can't open template $self->{MainData}{Template}\n";
	open(MK_RSC, ">./../db/ipv4/$data{FileName}") || die "Can't create ./../db/ipv4/$data{FileName}\n";

#	print Dumper %data;
	foreach(<Template>){
		trim($_);
		if ($_) {
#			if ((exists $self->{MainData}{VOLZ_MAC}) && ($self->{MainData}{VOLZ_MAC} ne '')) {
#				$_ =~ s/\#\#\#K\#\#\#//g;
#			} elsif ((exists $self->{MainData}{VAK_MAC}) && ($self->{MainData}{VAK_MAC} ne '')) {
#				$_ =~ s/\#\#\#P\#\#\#//g;
#			}
#			# Затираем региональные коменты
#			$_ =~ s/\#\#\#\w\#\#\#.*//g;

			@keys = ($_ =~ /\$([0-9a-zA-Z_\-]+)\$/g);
			# Если найден один ключ в строке
			if (@keys) {
				foreach $key (@keys) {
					$keyValue = $data{$key} if exists $data{$key};
					# Тут собираем темплейт
					$_ =~ s/\$$key\$/$keyValue/g if ($keyValue);
				}
			}
			# Затираем оставшиеся ключи
			$_ =~ s/\$[0-9a-zA-Z_\-]+\$//g;
			print MK_RSC $_."\n";
			undef $keyValue;
		} else {
			print MK_RSC $_."\n";
		}

	}

	close(MK_RSC);
	close(Template);
}



=cut

#################################################################
########################## Region Data ##########################
#################################################################

sub getWareHouse() {
	($self, %opts) = @_;
	my (@regionList, $choosedRegion);
	my (@loopbackList, $choosedLoopback);
	my ($key, $value);

	@regionList = $self->{Model}->getRegion();
	if (!$self->{Model}->{Error}) {

		RegioList:
		### Меню выбора региона
		$choosedRegion = $self->{View}->getRegion(
													RegionList => \@regionList,
													Default => (defined $self->{Region} && $self->{Region} ne '')? $self->{Region} : False
												);

		return False if !$choosedRegion;

		$self->{Region} = $choosedRegion;
		@loopbackList = $self->{Model}->getLoopback($choosedRegion);
		if (!$self->{Model}->{Error}) {

			### Меню выбора лупбека
			$choosedLoopback = $self->{View}->getLoopback(
															LoopbackList => \@loopbackList,
															Default => (defined $self->{RouterIP} && $self->{RouterIP} ne '')? $self->{RouterIP} : False
														);

			goto RegioList if !$choosedLoopback;

			### Вытаскиваем подсеть отделения
			$self->{Model}->getWhNet(
										RouterIP => $choosedLoopback
									);

			if ($self->{Model}->{Error}) {
				### Если настройки для региона не найдены тогда информируем пользователя
				$self->{View}->InfoWinBox(
											### Если не найдена языковая переменная тогда передаем сам ключ
											Message => ($self->{Lang}{$self->{Model}->{Error}}) ? $self->{Lang}{$self->{Model}->{Error}} : $self->{Model}->{Error}
										);
				undef $self->{Model}->{Error};
				return False;
			}

			### Вытаскиваем региональные настройки из БД
			$self->{Model}->getRegionData(
											Device => $self->{MainData}{Template},
											RegionID => ($choosedLoopback =~ /\d{1,3}\.(\d{1,3})\.\d{1,3}\.\d{1,3}/g)[0]
										);

			if ($self->{Model}->{Error}) {
				### Если настройки для региона не найдены тогда информируем пользователя
				$self->{View}->InfoWinBox(
											### Если не найдена языковая переменная тогда передаем сам ключ
											Message => ($self->{Lang}{$self->{Model}->{Error}}) ? $self->{Lang}{$self->{Model}->{Error}} : $self->{Model}->{Error}
										);
				undef $self->{Model}->{Error};
				return False;
			}

			### Переливаем все данные выбранные из БД с региональными настройками в главный хеш
			while (($key, $value) = each %{$self->{Model}->{RegionData}}) { $self->{MainData}{$key} = $value};

			$self->{RouterIP} = $choosedLoopback;
			$self->{MainData}{LO} = $choosedLoopback;
			$self->{MainData}{Device} = $self->{MainData}{Device};
			$self->{WhNumber} = $self->{Model}->getNumberWh($self->{Model}->{loData}{$choosedLoopback}{ID_1C});
			$self->{MainData}{Location} = Translit($self->{Model}->{loData}{$choosedLoopback}{Location});
			return True;

		} else {
			### Если лупбек не найден тогда информируем пользователя
			$self->{View}->InfoWinBox(
										### Если не найдена языковая переменная тогда передаем сам ключ
										Message => ($self->{Lang}{$self->{Model}->{Error}}) ? $self->{Lang}{$self->{Model}->{Error}} : $self->{Model}->{Error}
									);
			undef $self->{Model}->{Error};
			return False;
		}

	} else {
		### Если регион не найден тогда информируем пользователя
		$self->{View}->InfoWinBox(
									### Если не найдена языковая переменная тогда передаем сам ключ
									Message => ($self->{Lang}{$self->{Model}->{Error}}) ? $self->{Lang}{$self->{Model}->{Error}} : $self->{Model}->{Error}
								);
		undef $self->{Model}->{Error};
		return False;
	}
}

sub Unsuccessful() {
	($self, %opts) = @_;
	### Вьюха c
	$self->{View}->InfoWinBox(
								### Если не найдена языковая переменная тогда передаем сам ключ
								Message => $self->{Lang}{device_is_not_reboot_properly}
						);
}

sub Successful() {
	($self, %opts) = @_;
	### Вьюха c 100% и более прогрес баром
	$self->{View}->deviceIsUp(Percent => 100);
	sleep(2);
	$self->{View}->InfoWinBox(
							### Если не найдена языковая переменная тогда передаем сам ключ
							Message => $self->{Lang}{device_setup_is_successful}
						);
}

=cut
END {};
1;