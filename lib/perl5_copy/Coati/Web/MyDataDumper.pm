# First create a Data::Dumper that sorts the output hashes. This helps if you
# want to diff two databases. Adapted from code posted on Usenet by
# Jim Cromie <jcromie@uswest.com>

package Coati::Web::MyDataDumper;
use Data::Dumper;
use Carp; # needed for my overloaded implementation of _dump

# OVERLOAD 1 FUNCTION TO GET ORDERED DUMPING
# DELETE THE REST AND INHERIT IT INSTEAD,  NO MAINTENANCE!!
#
# twist, toil and turn;
# and recurse, of course.

# This is a local in Dumper(), which calls this function.
use vars qw( @ISA @post );

@ISA = qw ( Data::Dumper );

sub new
{
  my $type = shift;
  my $arrayRef = shift;

  my $dumper = Data::Dumper->new($arrayRef);

  bless $dumper, 'Coati::Web::MyDataDumper';
  return $dumper;
}

sub _dump
{
  my($s, $val, $name) = @_;

  my($sname);
  my($out, $realpack, $realtype, $type, $ipad, $id, $blesspad);

  $type = ref $val;
  $out = "";

  if ($type) {

    # prep it, if it looks like an object
    if ($type =~ /[a-z_:]/) {
      my $freezer = $s->{freezer};
      $val->$freezer() if $freezer && UNIVERSAL::can($val, $freezer);
    }

    ($realpack, $realtype, $id) =
      (overload::StrVal($val) =~ /^(?:(.*)\=)?([^=]*)\(([^\(]*)\)$/);

    # if it has a name, we need to either look it up, or keep a tab
    # on it so we know when we hit it later
    if (defined($name) and length($name)) {
      # keep a tab on it so that we dont fall into recursive pit
      if (exists $s->{seen}{$id}) {
#       if ($s->{expdepth} < $s->{level}) {
          if ($s->{purity} and $s->{level} > 0) {
            $out = ($realtype eq 'HASH')  ? '{}' :
              ($realtype eq 'ARRAY') ? '[]' :
                "''" ;
            push @post, $name . " = " . $s->{seen}{$id}[0];
          }
          else {
            $out = $s->{seen}{$id}[0];
            if ($name =~ /^([\@\%])/) {
              my $start = $1;
              if ($out =~ /^\\$start/) {
                $out = substr($out, 1);
              }
              else {
                $out = $start . '{' . $out . '}';
              }
            }
          }
          return $out;
#        }
      }
      else {
        # store our name
        $s->{seen}{$id} = [ (($name =~ /^[@%]/)     ? ('\\' . $name ) :
                             ($realtype eq 'CODE' and
                              $name =~ /^[*](.*)$/) ? ('\\&' . $1 )   :
                             $name          ),
                            $val ];
      }
    }

    $s->{level}++;
    $ipad = $s->{xpad} x $s->{level};

    if ($realpack) {          # we have a blessed ref
      $out = $s->{'bless'} . '( ';
      $blesspad = $s->{apad};
      $s->{apad} .= '       ' if ($s->{indent} >= 2);
    }

    if ($realtype eq 'SCALAR') {
      if ($realpack) {
        $out .= 'do{\\(my $o = ' . $s->_dump($$val, "\${$name}") . ')}';
      }
      else {
        $out .= '\\' . $s->_dump($$val, "\${$name}");
      }
    }
    elsif ($realtype eq 'GLOB') {
        $out .= '\\' . $s->_dump($$val, "*{$name}");
    }
    elsif ($realtype eq 'ARRAY') {
      my($v, $pad, $mname);
      my($i) = 0;
      $out .= ($name =~ /^\@/) ? '(' : '[';
      $pad = $s->{sep} . $s->{pad} . $s->{apad};
      ($name =~ /^\@(.*)$/) ? ($mname = "\$" . $1) :
        # omit -> if $foo->[0]->{bar}, but not ${$foo->[0]}->{bar}
        ($name =~ /^\\?[\%\@\*\$][^{].*[]}]$/) ? ($mname = $name) :
          ($mname = $name . '->');
      $mname .= '->' if $mname =~ /^\*.+\{[A-Z]+\}$/;
      for $v (@$val) {
        $sname = $mname . '[' . $i . ']';
        $out .= $pad . $ipad . '#' . $i if $s->{indent} >= 3;
        $out .= $pad . $ipad . $s->_dump($v, $sname);
        $out .= "," if $i++ < $#$val;
      }
      $out .= $pad . ($s->{xpad} x ($s->{level} - 1)) if $i;
      $out .= ($name =~ /^\@/) ? ')' : ']';
    }
   elsif ($realtype eq 'HASH') {
      my($k, $v, $pad, $lpad, $mname);
      $out .= ($name =~ /^\%/) ? '(' : '{';
      $pad = $s->{sep} . $s->{pad} . $s->{apad};
      $lpad = $s->{apad};
      ($name =~ /^\%(.*)$/) ? ($mname = "\$" . $1) :
        # omit -> if $foo->[0]->{bar}, but not ${$foo->[0]}->{bar}
        ($name =~ /^\\?[\%\@\*\$][^{].*[]}]$/) ? ($mname = $name) :
          ($mname = $name . '->');
      $mname .= '->' if $mname =~ /^\*.+\{[A-Z]+\}$/;
#      while (($k, $v) = each %$val)
      foreach $k (sort keys %$val)
      {
        my $nk = $s->_dump($k, "");
        $nk = $1 if !$s->{quotekeys} and $nk =~ /^[\"\']([A-Za-z_]\w*)[\"\']$/;
        $sname = $mname . '{' . $nk . '}';
        $out .= $pad . $ipad . $nk . " => ";

        # temporarily alter apad
        $s->{apad} .= (" " x (length($nk) + 4)) if $s->{indent} >= 2;
        $out .= $s->_dump($val->{$k}, $sname) . ",";
        $s->{apad} = $lpad if $s->{indent} >= 2;
      }
      if (substr($out, -1) eq ',') {
        chop $out;
        $out .= $pad . ($s->{xpad} x ($s->{level} - 1));
      }
      $out .= ($name =~ /^\%/) ? ')' : '}';
    }
    elsif ($realtype eq 'CODE') {
      $out .= 'sub { "DUMMY" }';
      carp "Encountered CODE ref, using dummy placeholder" if $s->{purity};
    }
    else {
      croak "Can\'t handle $realtype type.";
    }

    if ($realpack) { # we have a blessed ref
      $out .= ', \'' . $realpack . '\'' . ' )';
      $out .= '->' . $s->{toaster} . '()'  if $s->{toaster} ne '';
      $s->{apad} = $blesspad;
    }
    $s->{level}--;

  }
  else {                                 # simple scalar

    my $ref = \$_[1];
    # first, catalog the scalar
    if ($name ne '') {
      ($id) = ("$ref" =~ /\(([^\(]*)\)$/);
      if (exists $s->{seen}{$id}) {
        if ($s->{seen}{$id}[2]) {
          $out = $s->{seen}{$id}[0];
          #warn "[<$out]\n";
          return "\${$out}";
        }
      }
      else {
        #warn "[>\\$name]\n";
        $s->{seen}{$id} = ["\\$name", $ref];
      }
    }
    if (ref($ref) eq 'GLOB' or "$ref" =~ /=GLOB\([^()]+\)$/) {  # glob
      my $name = substr($val, 1);
      if ($name =~ /^[A-Za-z_][\w:]*$/) {
        $name =~ s/^main::/::/;
        $sname = $name;
      }
      else {
        $sname = $s->_dump($name, "");
        $sname = '{' . $sname . '}';
      }
      if ($s->{purity}) {
        my $k;
        local ($s->{level}) = 0;
        for $k (qw(SCALAR ARRAY HASH)) {
          my $gval = *$val{$k};
          next unless defined $gval;
          next if $k eq "SCALAR" && ! defined $$gval;  # always there

          # _dump can push into @post, so we hold our place using $postlen
          my $postlen = scalar @post;
          $post[$postlen] = "\*$sname = ";
          local ($s->{apad}) = " " x length($post[$postlen]) if $s->{indent} >= 2;
          $post[$postlen] .= $s->_dump($gval, "\*$sname\{$k\}");
        }
      }
      $out .= '*' . $sname;
    }
    elsif (!defined($val)) {
      $out .= "undef";
    }
    elsif ($val =~ /^-?[1-9]\d{0,8}$/) { # safe decimal number
      $out .= $val;
    }
    else {                               # string
      if ($s->{useqq}) {
        $out .= qquote($val, $s->{useqq});
      }
      else {
        $val =~ s/([\\\'])/\\$1/g;
        $out .= '\'' . $val .  '\'';
      }
    }
  }
  if ($id) {
    # if we made it this far, $id was added to seen list at current
    # level, so remove it to get deep copies
    if ($s->{deepcopy}) {
      delete($s->{seen}{$id});
    }
    elsif ($name) {
      $s->{seen}{$id}[2] = 1;
    }
  } return $out;
}
