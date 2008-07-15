#================
# FILE          : KIWIPatternsPlugin.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Jan-Christoph Bornschlegel <jcborn@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Module creating the "patterns" file
#               :
# STATUS        : Development
#----------------

package KIWIPatternsPlugin;

use strict;

use base "KIWIInstSourceBasePlugin";

sub new
{
  # ...
  # Create a new KIWIPatternsPlugin object
  # creates patterns file
  # ---
  my $class = shift;

  my $this = new KIWIInstSourceBasePlugin(shift);
  bless ($this, $class);

  $this->name("PatternsPlugin");
  $this->order(1);
### baustelle ###
  my $dir = $this->handler()->collect()->productData()->getInfo("DESCRDIR");
  $this->requiredDirs($dir);
  $this->description("Creates patterns file",
        	      "This is basicallly a ls listing");
  #$this->requires();
  $this->{m_media} = [1];
  return $this;
}
# /constructor



sub execute
{
  my $this = shift;
  if(not ref($this)) {
    return undef;
  }
  my $retval = 0;
  # sanity check:
  if($this->{m_ready} == 0) {
    return $retval;
  }

  my $dirname = $this->{m_handler}->baseurl()."/".$this->{m_handler}->mediaName();
  my $mult = $this->handler()->collect()->productData()->getVar("MULTIPLE_MEDIA");
  if( $mult ne "no") {
    $dirname .= $this->{m_media}->[0];
  }
  $dirname .= "/".$this->{m_requireddirs}->[0];

  if(!open(PAT, ">", "$dirname/patterns")) {
    die "Cannot create $dirname/patterns!";
  }
  if(!opendir(PATDIR, "$dirname")) {
    die "Cannot read $dirname!";
  }
  my @dirent = readdir(PATDIR);
  foreach(@dirent) {
    next if $_ !~ m{(.*[.]pat|.*[.]pat[.]gz)};
    print PAT "$_\n";
  }
  close(PATDIR);	
  close(PAT);	

  $retval = 1;
  return $retval;
}



1;

