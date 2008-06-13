
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

  #my $this  = {
  #  m_name	  => "PatternsPlugin",
  #  m_order	  => 1,
  #  m_requireddirs => ["suse/setup/descr"],
  #  m_media	  => [1],
  #  m_descr	  => ["Creates patterns file",
  #      	      "This is basicallly a ls listing"],
  #  m_requires	  => [],
  #  m_ready	  => 0,
  #};
  my $this = new KIWIInstSourceBasePlugin(shift);
  bless ($this, $class);

  $this->name("PatternsPlugin");
  $this->order(1);
  $this->requiredDirs("suse/setup/descr");
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


  my $dirname = $this->{m_handler}->baseurl()."/".$this->{m_handler}->mediaName().$this->{m_media}->[0]."/".$this->{m_requireddirs}->[0];
  if(!open(PAT, ">", "$dirname/patterns")) {
    die "Cannot create $this->{m_basesubdir}->{'1'}/suse/setup/descr/patterns!";
  }
  if(!opendir(PATDIR, "$dirname")) {
    die "Cannot read $this->{m_basesubdir}->{'1'}/suse/setup/descr/!";
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

