#!/usr/bin/env perl
package Modules::Alignment::BlastResults;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../";
use IO::File;
use Log::Log4perl;
use Carp;

sub new {
	my ($class) = shift;
	my $self = {};
	bless( $self, $class );
	$self->_initialize(@_);
	return $self;
}

=head3 logger

Stores a logger object for the module.

=cut

sub logger{
	my $self=shift;
	$self->{'_logger'} = shift // return $self->{'_logger'};
}


sub _outFH{
	my $self=shift;
	$self->{'__outFH'} = shift // return $self->{'__outFH'};
}


#we want to store UNDEF in this variable, which makes the standard way always return the stored value, rather than setting it to UNDEF.
sub _setStoredLine{
	my $self=shift;
	$self->{'__storedLine'} = shift;	
}

sub _getStoredLine{
	my $self = shift;
	return $self->{'__storedLine'}
}



#methods
sub _initialize {
	my ($self) = shift;

	#logging
	$self->logger(Log::Log4perl->get_logger());
	$self->logger->debug("Logger initialized in Modules::Alignment::BlastResults");
	my $outFile = shift // $self->logger->logdie("No file sent to BlastResults");
	my $settings = shift // $self->logger->logdie("Settings required in BlastResults");
	$self->settings($settings);

	$self->_outFH(IO::File->new('<' . $outFile)) // $self->logger->logdie("$!");
	
	#set the first line in _storedLine to prevent infinite looping
	$self->_setStoredLine($self->_outFH->getline());
	
	$self->_alleleCount({});
}

sub settings{
	my $self=shift;
	$self->{'_settings'} = shift // return $self->{'_settings'};	
}

sub _alleleCount{
	my $self=shift;
	$self->{'__alleleCount'} = shift // return $self->{'__alleleCount'};	
}

sub getNextResult{
	my $self=shift;
		
	my %results;
	my $line = $self->_getStoredLine(); #on object creation, this is initialized with the first line
	#$self->logger->debug("stored line: $line");

	while($line){	
	
		my $nextLine = $self->_outFH->getline();
		$self->_setStoredLine($nextLine);	
		
		my @nextLa;
		if(defined $nextLine){
			$nextLine =~ s/\R//g;
			@nextLa = split("\t",$nextLine);
		}
		else{
			$self->logger->debug("nextLine UNDEF");
		}
		
		$line =~ s/\R//g;		
		my @la = split("\t",$line);
		$self->logger->debug("Current hit: $la[0]");		
		$self->logger->debug("Current query: $la[1]");
		#'outfmt'=>'"6 
		# [0]sseqid 
		# [1]qseqid 
		# [2]sstart 
		# [3]send 
		# [4]qstart 
		# [5]qend 
		# [6]slen 
		# [7]qlen 
		# [8]pident 
		# [9]length"',
		# [10]sseq,
		# [11]qseq


		my $sName = $self->settings->getGenomeNameFromContig($la[0]);
					
		if($self->_getPercentId($la[7],$la[8],$la[4],$la[5]) > $self->settings->percentIdentityCutoff){			
			$self->logger->debug("Passes percent identity cutoff");
			
			my $alleleCount = $self->_alleleCount->{$sName} // 0;
			$self->logger->debug("$sName has $alleleCount alleles");
			if($alleleCount >= $self->settings->allelesToKeep){
				$self->logger->debug("$la[1] defined for $la[0], doing nothing")
				#nothing
			}
			else{
				$alleleCount++;				
				$self->_alleleCount->{$sName}=$alleleCount;
			
				$self->logger->debug("Adding result for $sName, alleleCount $alleleCount");
				push @{$results{$sName}}, \@la;
			}				
		}		
		
		if(!defined $nextLa[0]){
			$self->logger->debug("RETURN: Next not defined\n\n");
			$self->_alleleCount({});
			return \%results;
		}
		elsif($la[1] ne $nextLa[1]){
			$self->logger->debug("RETURN: $la[1] NE to $nextLa[1]");
			$self->_alleleCount({});
			return \%results;			
		}
		else{
			$line = $nextLine;
		}
	}
}


=head2

Get the current allele count for the query sequence.

=cut


sub _getPercentId{
	my $self=shift;
	my $qlen =shift // $self->logger->logdie("Missing qlen");
	my $pident =shift // $self->logger->logdie("Missing pident");
	my $qstart = shift // $self->logger->logdie("Missing qstart");
	my $qend =shift // $self->logger->logdie("Missing qend");

	my $queryHitLength = abs($qend - $qstart) +1;
	
	my $percentId = $queryHitLength / $qlen * $pident;
	 #$self->logger->info("queryHitLength: $queryHitLength");
	 # $self->logger->info("qlen: $qlen");
	 #$self->logger->info("pident: $pident");
	 #$self->logger->info("percentId: $percentId");
	return $percentId;
}

1;
