#!/usr/bin/perl -w
use strict;
use JSON;
use Data::Dumper;
use Carp;

$/ = "\r\n";

my $data = {};
init();

open(FOOD, "<FOOD_DES.txt") || die "unable to open FOOD_DES.txt: $!";
my @labels  = qw( NDB_No FdGrp_Cd Long_Desc Shrt_Desc ComName ManufacName Survey Ref_desc Refuse SciName N_Factor Pro_Factor Fat_Factor CHO_Factor );
my @numeric = qw(                                                                         Refuse         N_Factor Pro_Factor Fat_Factor CHO_Factor );
my $count = 0;
while(<FOOD>) {
	chomp;
	my %db;
	@db{@labels} = get_fields($_);
	numify(\%db, \@numeric);
	add_nut_data(\%db, $db{NDB_No});
	add_fd_group(\%db, $db{FdGrp_Cd});
	add_langual(\%db, $db{NDB_No});
	add_weight(\%db, $db{NDB_No});
	next unless $db{NDB_No} eq "02001";
	print encode_json(\%db);
	last if ++$count == 1;
}

sub init {
	my $datafile = 'data.dat';
	if (-e $datafile) {
		print "loading data from $datafile\n";
		open(DATA, "<$datafile") || die "unable to open $datafile: $!";
		my $dat = do { local $/; <DATA> };
		$data = decode_json($dat);
		close(DATA) || die "unable to close $datafile: $!";
		print "done loading\n";
	}
	else {
		load_nutr_def($data);
		load_nut_data($data);
		load_fd_group($data);
		load_langual($data);
		load_langdesc($data);
		load_weight($data);
		open(DATA, ">$datafile") || die "unable to open $datafile: $!";
		print DATA encode_json($data);
		close(DATA) || die "unable to close $datafile: $!";
	}
}

sub load_weight {
	my $data = shift;
	file_loader($data, "WEIGHT", "NDB_No", 
		[qw( NDB_No Seq Amount Msre_Desc Gm_Wgt Num_Data_Pts Std_Dev )], 
		[qw(        Seq Amount           Gm_Wgt )]
	);
}

sub load_nut_data {
	my $data = shift;
	file_loader($data, "NUT_DATA", "NDB_No", 
		[qw( NDB_No Nutr_No Nutr_Val Num_Data_Pts Std_Error Src_Cd Deriv_Cd Ref_NDB_No Add_Nutr_Mark Num_Studies Min Max DF Low_EB Up_EB Stat_cmt AddMod_Date CC )],
		[qw(                Nutr_Val Num_Data_Pts Std_Error                                          Num_Studies Min Max DF Low_EB Up_EB                         )]
	);
}

sub load_langual {
	my $data = shift;
	file_loader($data, "LANGUAL", "NDB_No", [qw( NDB_No Factor_Code )], [qw()] );
}

sub load_langdesc {
	my $data = shift;
	file_loader($data, "LANGDESC", "Factor_Code", [qw( Factor_Code Description )], [qw()] );
}

sub load_fd_group {
	my $data = shift;
	file_loader($data, "FD_GROUP", "FdGrp_Cd", [qw( FdGrp_Cd FdGrp_Desc )], [qw()] );
}

sub load_nutr_def {
	my $data = shift;
	file_loader($data, "NUTR_DEF", "Nutr_No", 
		[qw( Nutr_No Units Tagname NutrDesc Num_Dec SR_Order )], 
		[qw(                                Num_Dec SR_Order )] 
	);
}

sub file_loader {
	my $data    = shift;
	my $file    = shift;
	my $keyname = shift;
	my $fields  = shift;
	my $numbers = shift;

	my $useArray = $file =~ /LANGUAL|NUT_DATA|WEIGHT/ ? 1 : 0;

	my $filename = "$file.txt";
	open(FILE, "<$filename") || die "unable to open $filename: $!";

	print "loading $filename\n";
	my $count = 0;
	while(<FILE>) {
		chomp;
		my %db;
		@db{@{$fields}} = get_fields($_);

		numify(\%db, $numbers);

		my $key = $db{$keyname};
		delete($db{$keyname});
		if ($useArray) {
			push(@{$data->{$file}{$key}{data}}, \%db);
		}
		else {
			$data->{$file}{$key}{data} = \%db;
		}
		print "loading row " . $count++ . "\r";
	}
	print "\ndone loading\n";
	close(FILE) || die "unable to close $filename: $!";
}

sub get_fields {
	my $line = shift;
	return map { s/(^~)|(~$)//g; if(length($_)==0) { undef($_) }; $_ } split(/\^/, $_);
}

sub numify {
	my $db = shift;
	my $numbers = shift;

	# Numify the numbers for JSON encoding
	foreach (@{$numbers}) { next unless defined($db->{$_}); $db->{$_} += 0 }
}

sub add_nut_data {
	my $db = shift;
	my $id = shift;
	foreach my $nut (@{$data->{NUT_DATA}{$id}{data}}) {
		my $key = $nut->{Nutr_No};
		my $label = $key;
		$db->{"Nut_Data"}{$label} = { %$nut, %{$data->{NUTR_DEF}{$key}{data}} };
		delete($db->{"Nut_Data"}{$label}{Nutr_No});
	}
}

sub add_fd_group {
	my $db = shift;
	my $id = shift;
	foreach my $key (keys %{$data->{FD_GROUP}{$id}{data}}) {
		$db->{$key} = $data->{FD_GROUP}{$id}{data}{$key};
	}
}

sub add_langual {
	my $db = shift;
	my $id = shift;
	foreach my $lang (@{$data->{LANGUAL}{$id}{data}}) {
		my $factor_code = $lang->{Factor_Code};
		$db->{LanguaL}{$factor_code} = $data->{LANGDESC}{$factor_code}{data}{Description};
	}
}

sub add_weight {
	my $db = shift;
	my $id = shift;
	foreach my $weight (@{$data->{WEIGHT}{$id}{data}}) {
		push(@{$db->{Weight}}, $weight);
	}
}
