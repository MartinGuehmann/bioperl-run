# $Id$
#
# BioPerl module for Bio::Tools::Run::Phylo::PAML::Evolver
#
#       based on the Bio::Tools::Run::Phylo::PAML::Codeml
#       by Jason Stajich <jason-at-bioperl.org>
#
# Cared for by Albert Vilella <avilella-AT-gmail-DOT-com>
#
# Copyright Albert Vilella
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Tools::Run::Phylo::PAML::Evolver - Wrapper aroud the PAML program evolver

=head1 SYNOPSIS

  use Bio::Tools::Run::Phylo::PAML::Evolver;

  my $evolver = new Bio::Tools::Run::Phylo::PAML::Evolver();

  # Get a $tree object somehow
  $evolver->tree($tree);

  # FIXME: evolver generates a tree (first run with option 1 or 2)?

  # One or more alns are created
  my @alns = $evolver->run();

  ####

  # Or with all the data coming from a previous PAML run
  my $parser = new Bio::Tools::Phylo::PAML
    (
     -file => "$mlcfile",
     -dir => "$dir",
    );
  my $result = $parser->next_result();
  my $tree = $result->next_tree;
  $evolver->tree($tree);

  # Option (6) Simulate codon data sets      (use MCcodon.dat)?
  # For codon frequencies, maybe something similar to:
  my @codon_freqs = $result->get_CodonFreqs();
  $evolver->set_CodonFreqs(@codon_freqs);

  # FIXME: something similar for nucleotide frequencies:
  # Option (5) Simulate nucleotide data sets (use MCbase.dat)?

  # FIXME: something similar for aa parameters:
  # Option (7) Simulate amino acid data sets (use MCaa.dat)?

=head1 DESCRIPTION

This is a wrapper around the evolver program of PAML (Phylogenetic
Analysis by Maximum Likelihood) package of Ziheng Yang.  See
http://abacus.gene.ucl.ac.uk/software/paml.html for more information.

This module is more about generating the properl MCmodel.ctl file and
will run the program in a separate temporary directory to avoid
creating temp files all over the place.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org              - General discussion
  http://bioperl.org/MailList.shtml  - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via the
web:

  http://bioperl.org/bioperl-bugs/

=head1 AUTHOR - Albert Vilella

Email avilella-AT-gmail-DOT-com

=head1 CONTRIBUTORS

Additional contributors names and emails here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::Tools::Run::Phylo::PAML::Evolver;
use vars qw(@ISA %VALIDVALUES $MINNAMELEN $PROGRAMNAME $PROGRAM);
use strict;
use Bio::Root::Root;
use Bio::AlignIO;
use Bio::TreeIO;
use Bio::Tools::Run::WrapperBase;
use Bio::Tools::Phylo::PAML;
use Cwd;

@ISA = qw(Bio::Root::Root Bio::Tools::Run::WrapperBase);

=head2 Default Values

Valid and default values for evolver programs are listed below.  The
default values are always the first one listed.  These descriptions
are essentially lifted from the example MCcodon.dat file and pamlDOC
documentation provided by the author.

Stub:

B<option1> specifies something.

B<option2> specifies something else.


INCOMPLETE DOCUMENTATION OF ALL METHODS

=cut

BEGIN { 

    $MINNAMELEN = 25;
    $PROGRAMNAME = 'evolver' . ($^O =~ /mswin/i ?'.exe':'');
    if( defined $ENV{'PAMLDIR'} ) {
	$PROGRAM = Bio::Root::IO->catfile($ENV{'PAMLDIR'},$PROGRAMNAME). ($^O =~ /mswin/i ?'.exe':'');;
    }
   
    # valid values for parameters, the default one is always
    # the first one in the array
    # much of the documentation here is lifted directly from the MCcodon.dat
    # example file provided with the package

    %VALIDVALUES = 
        ( 

         # FIXME: there should be a 6-7-8 option that fits MCcodon or MCbase or MCaa
         'outfmt'    => [0,1], 
         #     0           * 0:paml format (mc.paml); 1:paup format (mc.paup)
         # random number seed (odd number)
         # FIXME: can I set seed to null here and ask for it later?
         'seed' => NULL,
         # numseq can actually be calculated from the tree external nodes
         # nucleotide sites
         'nuclsites' => '1000',
         # replicates
         'replicates' => '1',
         # FIXME: check min and max in evolver
         # tree length; use -1 if tree has absolute branch lengths
         # Note that tree length and branch lengths under the codon model are
         # measured by the expected number of nucleotide substitutions per codon
         # (see Goldman & Yang 1994).  For amino acid models, they are defined as
         # the expected number of amino acid changes per amino acid site.
         'tree_length' => '1.5',
         # omega
         'omega' => '0.3',
         # kappa
         'kappa' => '5',
         # FIXME: codon freqs or nt freqs should always come from an object?
         # FIXME: this only for MCbase.dat ?
         # model: 0:JC69, 1:K80, 2:F81, 3:F84, 4:HKY85, 5:T92, 6:TN93, 7:REV
         # FIXME: this applies to only some models?
         # 10 5 1 2 3 * kappa or rate parameters in model
         # FIXME: this applies to only MCbase.dat ?
         # 0.5  4     * <alpha>  <#categories for discrete gamma>
        ); # end of validvalues
}

=head2 program_name

 Title   : program_name
 Usage   : $factory->program_name()
 Function: holds the program name
 Returns:  string
 Args    : None

=cut

sub program_name {
        return 'evolver';
}

=head2 program_dir

 Title   : program_dir
 Usage   : ->program_dir()
 Function: returns the program directory, obtiained from ENV variable.
 Returns:  string
 Args    :

=cut

sub program_dir {
        return Bio::Root::IO->catfile($ENV{PAMLDIR}) if $ENV{PAMLDIR};
}


=head2 new

 Title   : new
 Usage   : my $obj = new Bio::Tools::Run::Phylo::PAML::Evolver();
 Function: Builds a new Bio::Tools::Run::Phylo::PAML::Evolver object 
 Returns : Bio::Tools::Run::Phylo::PAML::Evolver
           -save_tempfiles => boolean to save the generated tempfiles and
                              NOT cleanup after onesself (default FALSE)
           -tree => the Bio::Tree::TreeI object (FIXME: optional if this is done in a first run)
           -params => a hashref of PAML parameters (all passed to set_parameter)
           -executable => where the evolver executable resides

See also: L<Bio::Tree::TreeI>

=cut

sub new {
  my($class,@args) = @_;

  my $self = $class->SUPER::new(@args);
#   $self->{'_branchLengths'} = 0;
  my ($aln, $tree, $st, $params, $exe, 
      $ubl) = $self->_rearrange([qw(TREE SAVE_TEMPFILES PARAMS EXECUTABLE)],
				    @args);
  defined $tree && $self->tree($tree);
  defined $st  && $self->save_tempfiles($st);
  defined $exe && $self->executable($exe);

  $self->set_default_parameters();
  if( defined $params ) {
      if( ref($params) !~ /HASH/i ) { 
	  $self->warn("Must provide a valid hash ref for parameter -FLAGS");
      } else {
	  map { $self->set_parameter($_, $$params{$_}) } keys %$params;
      }
  }
  return $self;
}


=head2 prepare

 Title   : prepare
 Usage   : my $rundir = $evolver->prepare($aln);
 Function: prepare the evolver analysis using the default or updated parameters
           the alignment parameter must have been set
 Returns : value of rundir
 Args    : L<Bio::Align::AlignI> object,
	   L<Bio::Tree::TreeI> object [optional]

=cut

sub prepare {
   my ($self,$aln,$tree) = @_;
   unless ( $self->save_tempfiles ) {
       # brush so we don't get plaque buildup ;)
       $self->cleanup();
   }
   $tree = $self->tree unless $tree;
   my ($tempdir) = $self->tempdir();
   my ($tempseqFH,$tempseqfile);
   #FIXME: split the files if replicates > 1 or maybe force paup outfmt?
   #    if( ! ref($aln) && -e $aln ) { 
   #        $tempseqfile = $aln;
   #    } else { 
   #        ($tempseqFH,$tempseqfile) = $self->io->tempfile
   # 	   ('-dir' => $tempdir, 
   # 	    UNLINK => ($self->save_tempfiles ? 0 : 1));
   #        my $alnout = new Bio::AlignIO('-format'      => 'phylip',
   # 				     '-fh'          => $tempseqFH,
   #                                      '-interleaved' => 0,
   #                                      '-idlength'    => $MINNAMELEN > $aln->maxdisplayname_length() ? $MINNAMELEN : $aln->maxdisplayname_length() +1);
   #        $alnout->write_aln($aln);
   #        $alnout->close();
   #        undef $alnout;   
   #        close($tempseqFH);
   #    }
   # now let's print the MCcodon.dat file.
   # many of the these programs are finicky about what the filename is 
   # and won't even run without the properly named file.  Ack
   
   # FIXME: we should do the appropriate here if we are simulating codons, nts o aa.
   my $evolver_ctl = "$tempdir/MCcodon.dat";
   open(EVOLVER, ">$evolver_ctl") or $self->throw("cannot open $evolver_ctl for writing");
   print EVOLVER "seqfile = $tempseqfile\n";

   my $outfile = $self->outfile_name;

   # FIXME: What if we write the tree inside $evolver_ctl
#    my ($temptreeFH,$temptreefile);
#    if( ! ref($tree) && -e $tree ) { 
#        $temptreefile = $tree;
#    } else { 
#        ($temptreeFH,$temptreefile) = $self->io->tempfile
# 	   ('-dir' => $tempdir, 
# 	    UNLINK => ($self->save_tempfiles ? 0 : 1));

#        my $treeout = new Bio::TreeIO('-format' => 'newick',
# 				     '-fh'     => $temptreeFH);
#        $treeout->write_tree($tree);
#        $treeout->close();
#        close($temptreeFH);
#    }
#    print EVOLVER "treefile = $temptreefile\n";

#    print EVOLVER "outfile = $outfile\n";
#    my %params = $self->get_parameters;

##    FIXME: params follow an order, they are not a hash. Do we have
##    an example of this in bioperl-run?

#    while( my ($param,$val) = each %params ) {
#        print EVOLVER "$param = $val\n";
#    }
#    close(EVOLVER);
#    my ($rc,$parser) = (1);
#    {
#        my $cwd = cwd();
#        my $exit_status;
#        chdir($tempdir);
#    }
   return $tempdir;
}


=head2 run

 Title   : run
 Usage   : my ($rc,$parser) = $evolver->run($aln);
 Function: run the evolver analysis using the default or updated parameters
           the alignment parameter must have been set
 Returns : Return code, L<Bio::Tools::Phylo::PAML>
 Args    : L<Bio::Align::AlignI> object,
	   L<Bio::Tree::TreeI> object [optional]

=cut

sub run {

    # FIXME: We should look for the stuff we prepared in the prepare method here
   my ($rc,$parser) = (1);
   {
       my $cwd = cwd();
       my $exit_status;
       chdir($tmpdir);
       my $evolverexe = $self->executable();
       $self->throw("unable to find or run executable for 'evolver'") unless $evolverexe && -e $evolverexe && -x _;
       if( $self->{'_branchLengths'} ) { 
	   open(RUN, "echo $self->{'_branchLengths'} | $evolverexe |") or $self->throw("Cannot open exe $evolverexe");
       } else {
	   open(RUN, "$evolverexe |") or $self->throw("Cannot open exe $evolverexe");
       }
       my @output = <RUN>;
       $exit_status = close(RUN);
       $self->error_string(join('',@output));
       if( (grep { /\berr(or)?: /io } @output)  || !$exit_status) {
	   $self->warn("There was an error - see error_string for the program output");
	   $rc = 0;
       }
       #### FIXME: Will we parse/test the resulting alns? Shouldn't
       #### we, this can go away
       eval {
	   $parser = new Bio::Tools::Phylo::PAML(-file => "$tmpdir/mlc", 
						 -dir => "$tmpdir");

       };
       if( $@ ) {
	   $self->warn($self->error_string);
       }
       chdir($cwd);
       ####
   }
   unless ( $self->save_tempfiles ) {
      unlink("$evolver_ctl");
      $self->cleanup();
   }
   return ($rc,$parser);
}

=head2 error_string

 Title   : error_string
 Usage   : $obj->error_string($newval)
 Function: Where the output from the last analysus run is stored.
 Returns : value of error_string
 Args    : newvalue (optional)


=cut

sub error_string{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'error_string'} = $value;
    }
    return $self->{'error_string'};

}

=head2 tree

 Title   : tree
 Usage   : $evolver->tree($tree, %params);
 Function: Get/Set the L<Bio::Tree::TreeI> object
 Returns : L<Bio::Tree::TreeI> 
 Args    : [optional] $tree => L<Bio::Tree::TreeI>,
           [optional] %parameters => hash of tree-specific parameters:
                  branchLengths: 0, 1 or 2
                  out

 Comment : We could potentially add support for running directly on a file
           but we shall keep it simple
 See also: L<Bio::Tree::Tree>

=cut

sub tree {
   my ($self, $tree, %params) = @_;
   if( defined $tree ) { 
       if( ! ref($tree) || ! $tree->isa('Bio::Tree::TreeI') ) { 
	   $self->warn("Must specify a valid Bio::Tree::TreeI object to the alignment function");
       }
       $self->{'_tree'} = $tree;
       # FIXME: I think we dont need this in Evolver
#        if ( defined $params{'_branchLengths'} ) {
# 	 my $ubl = $params{'_branchLengths'};
# 	 if ($ubl !~ m/^(0|1|2)$/) {
# 	   $self->throw("The branchLengths parameter to tree() must be 0 (ignore), 1 (initial values) or 2 (fixed values) only");
# 	 }
# 	 $self->{'_branchLengths'} = $ubl;
#        }
   }
   return $self->{'_tree'};
}

=head2 get_parameters

 Title   : get_parameters
 Usage   : my %params = $self->get_parameters();
 Function: returns the list of parameters as a hash
 Returns : associative array keyed on parameter names
 Args    : none


=cut

sub get_parameters{
   my ($self) = @_;
   # we're returning a copy of this
   return %{ $self->{'_evolverparams'} };
}


=head2 set_parameter

 Title   : set_parameter
 Usage   : $evolver->set_parameter($param,$val);
 Function: Sets a evolver parameter, will be validated against
           the valid values as set in the %VALIDVALUES class variable.  
           The checks can be ignored if one turns off param checks like this:
             $evolver->no_param_checks(1)
 Returns : boolean if set was success, if verbose is set to -1
           then no warning will be reported
 Args    : $param => name of the parameter
           $value => value to set the parameter to
 See also: L<no_param_checks()>

=cut

sub set_parameter{
   my ($self,$param,$value) = @_;
   unless ($self->{'no_param_checks'} == 1) {
       if ( ! defined $VALIDVALUES{$param} ) { 
           $self->warn("unknown parameter $param will not be set unless you force by setting no_param_checks to true");
           return 0;
       } 
       if ( ref( $VALIDVALUES{$param}) =~ /ARRAY/i &&
            scalar @{$VALIDVALUES{$param}} > 0 ) {
       
           unless ( grep { $value eq $_ } @{ $VALIDVALUES{$param} } ) {
               $self->warn("parameter $param specified value $value is not recognized, please see the documentation and the code for this module or set the no_param_checks to a true value");
               return 0;
           }
       }
   }
   $self->{'_evolverparams'}->{$param} = $value;
   return 1;
}

=head2 set_default_parameters

 Title   : set_default_parameters
 Usage   : $evolver->set_default_parameters(0);
 Function: (Re)set the default parameters from the defaults
           (the first value in each array in the 
	    %VALIDVALUES class variable)
 Returns : none
 Args    : boolean: keep existing parameter values


=cut

sub set_default_parameters{
   my ($self,$keepold) = @_;
   $keepold = 0 unless defined $keepold;
   
   while( my ($param,$val) = each %VALIDVALUES ) {
       # skip if we want to keep old values and it is already set
       next if( defined $self->{'_evolverparams'}->{$param} && $keepold);
       if(ref($val)=~/ARRAY/i ) {
	   $self->{'_evolverparams'}->{$param} = $val->[0];
       }  else { 
	   $self->{'_evolverparams'}->{$param} = $val;
       }
   }
}


=head1 Bio::Tools::Run::WrapperBase methods

=cut

=head2 no_param_checks

 Title   : no_param_checks
 Usage   : $obj->no_param_checks($newval)
 Function: Boolean flag as to whether or not we should
           trust the sanity checks for parameter values  
 Returns : value of no_param_checks
 Args    : newvalue (optional)


=cut

sub no_param_checks{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'no_param_checks'} = $value;
    }
    return $self->{'no_param_checks'};
}


=head2 save_tempfiles

 Title   : save_tempfiles
 Usage   : $obj->save_tempfiles($newval)
 Function: 
 Returns : value of save_tempfiles
 Args    : newvalue (optional)


=cut

=head2 outfile_name

 Title   : outfile_name
 Usage   : my $outfile = $evolver->outfile_name();
 Function: Get/Set the name of the output file for this run
           (if you wanted to do something special)
 Returns : string
 Args    : [optional] string to set value to


=cut


=head2 tempdir

 Title   : tempdir
 Usage   : my $tmpdir = $self->tempdir();
 Function: Retrieve a temporary directory name (which is created)
 Returns : string which is the name of the temporary directory
 Args    : none


=cut

=head2 cleanup

 Title   : cleanup
 Usage   : $evolver->cleanup();
 Function: Will cleanup the tempdir directory after a PAML run
 Returns : none
 Args    : none


=cut

=head2 io

 Title   : io
 Usage   : $obj->io($newval)
 Function:  Gets a L<Bio::Root::IO> object
 Returns : L<Bio::Root::IO>
 Args    : none


=cut

sub DESTROY {
    my $self= shift;
    unless ( $self->save_tempfiles ) {
	$self->cleanup();
    }
    $self->SUPER::DESTROY();
}

1;
