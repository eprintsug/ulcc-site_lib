# disable registration by default
$c->{allow_web_signup} = 0;
$c->{plugins}->{"Screen::Register"}->{actions}->{register}->{appears}->{key_tools} = undef;

# removing the default order makes simple search revert to 'by relevance'
$c->{search}->{simple}->{default_order} = undef;

#Need to start check for orcid as everyone is trying to add it  these days ;)
my $orcid_present = 0;
for(@{$c->{fields}->{user}}){
	$orcid_present = 1 if( $_->{name} eq "orcid" );
}
if( !$orcid_present ){
    push @{ $c->{fields}->{user} },
    {
        name => "orcid",
        type => "id"
    };
}


# add generic staffid field to user dataset
push @{ $c->{fields}->{user} },
{
	name => "staffid",
	type => "id"
}
;

# never timeout browse view cache
for( @{ $c->{browse_views} } )
{
    $_->{max_menu_age} = 9**9**9; # inf
    $_->{max_list_age} = 9**9**9; # inf
}

# always include archive ID in log messages
$c->{log} = sub
{
	my( $repository, $message ) = @_;

	print STDERR "[".$repository->get_id()."] ".$message."\n";
};

# disable multiple confusing feed options
$c->{plugins}->{"Export::RSS"}->{params}->{disable} = 1;
$c->{plugins}->{"Export::RSS2"}->{params}->{name} = "RSS";

# AH 21/09/2016: re-enabling Export::Atom plugin as SWORD intergration and
# CRUD.pm require it
# $c->{plugins}->{"Export::Atom"}->{params}->{disable} = 1;

# Stop eprints from publicly displaying personal information in exports 

push @{ $c->{fields}->{eprint} },  { name=>"contact_email", type=>"email", required=>0, can_clone=>0, export_as_xml=>0, replace_core=>1 };

#Fix ordering for creators_name
#Sticking familyname and given name together ordering as if a single string results in nonsense eg:

#Lamb, C. (1)
#Lambert, Jodie (1)
#Lambie, John (1)
#Lamb, Tracey J. (1)
#
#which should be 
#
#Lamb, C. (1)
#Lamb, Tracey J. (1)
#Lambert, Jodie (1)
#Lambie, John (1)

#Using this function to order fixes this problem
$c->{name_orderval} = sub
{
    my ($field, $value, $dataset) = @_;
    return $value->{family} . '$$$$$' . $value->{given};
};

for my $field (@{$c->{fields}->{eprint}}){
    if(grep $field->{name} eq $_, qw/creators editors contributors/){
        for my $sub (@{$field->{fields}}){
            #sort out ordervals
            if($sub->{sub_name} eq "name"){
                $sub->{make_single_value_orderkey} = 'name_orderval';
            }
            #don't eport possible emails
            if($sub->{sub_name} eq "id"){
                $sub->{export_as_xml} = 0;
            }
        }
    }
}

#The default validate_field does not check that an int is an int.
#Only worth using if sql_mode is not strict (see below)

$c->{validate_field} = sub
{
	my( $field, $value, $repository, $for_archive ) = @_;

	my $xml = $repository->xml();

	# only apply checks if the value is set
	return () if !EPrints::Utils::is_set( $value );

	my @problems = ();

	# CHECKS IN HERE

	my $values = ref($value) eq "ARRAY" ? $value : [$value];

	# closure for generating the field link fragment
	my $f_fieldname = sub {
		my $f = defined $field->property( "parent" ) ? $field->property( "parent" ) : $field;
		my $fieldname = $xml->create_element( "span", class=>"ep_problem_field:".$f->get_name );
		$fieldname->appendChild( $f->render_name( $repository ) );
		return $fieldname;
	};
	
    # Loop over actual individual values to check URLs, names and emails
	foreach my $v (@$values)
	{
		next unless EPrints::Utils::is_set( $v );

		if( $field->isa( "EPrints::MetaField::Url" ) )
		{
			# Valid URI check (very loose)
			if( $v !~ /^\w+:/ )
			{
				push @problems,
					$repository->html_phrase( "validate:missing_http",
						fieldname=>&$f_fieldname );
			}
		}
		elsif( $field->isa( "EPrints::MetaField::Name" ) )
		{
			# Check a name has a family part
			if( !EPrints::Utils::is_set( $v->{family} ) )
			{
				push @problems,
					$repository->html_phrase( "validate:missing_family",
						fieldname=>&$f_fieldname );
			}
			# Check a name has a given part
			elsif( !EPrints::Utils::is_set( $v->{given} ) )
			{
				push @problems,
					$repository->html_phrase( "validate:missing_given",
						fieldname=>&$f_fieldname );
			}
		}
		elsif( $field->isa( "EPrints::MetaField::Email" ) )
		{
			# Check an email looks "ok". Just checks it has only one "@" and no
			# spaces.
			if( $v !~ /^[^ \@]+\@[^ \@]+$/ )
			{
				push @problems,
					$repository->html_phrase( "validate:bad_email",
						fieldname=>&$f_fieldname );
			}
		}
		elsif( $field->isa( "EPrints::MetaField::Float" ) )
		{
			# Valid Float (Will warn if value is not a float, if DB not strict it will set, but nice to let people know)
            #   accept positive and negative value (+|-)
            #   match digits
            #   optionally match a decimal point followed bydigits
			if( $v !~ /[+-]?([0-9]*?[.])?[0-9]+$/ )
			{
				push @problems,
					$repository->html_phrase( "validate:not_a_float",
						fieldname=>&$f_fieldname );
			}
		}
		elsif( $field->isa( "EPrints::MetaField::Int" ) )
		{
			# Valid Int (Will warn if value is not an int, if DB not strict it will truncate and set, but nice to let people know)
			if( $v !~ /^\d+$/ )
			{
				push @problems,
					$repository->html_phrase( "validate:not_an_integer",
						fieldname=>&$f_fieldname );
			}
		}


		# Check for overly long values
		# Applies to all subclasses of Id: Text, Longtext, Url etc.
		if( $field->isa( "EPrints::MetaField::Id" ) )
		{
			if( length($v) > $field->property( "maxlength" ) )
			{
				push @problems,
					$repository->html_phrase( "validate:truncated",
						fieldname=>&$f_fieldname );
			}
		}
	}

	return( @problems );
};

# If SQL mode is strict then we need to check the int before it get's anywhere near the database
# This will truncate the non-int down to as much int as it can and set the value
# This in turn will make any validation (see above) obsolete so probably some js validation should go with this

{

    package EPrints::MetaField::Int;

    sub set_value
    {
        my( $self, $object, $value ) = @_;
        
        #Don't do this if it is a float....
        if($self->get_type =~ /float/){
            return $self->SUPER::set_value($object, $value);
        }
        # Or an array or arrayref (multiplr field)
        if(ref($value) =~ /ARRAY/){
            return $self->SUPER::set_value($object, $value);
        }
        if(defined $value && $value !~ /^\d+$/){
            my $ov = $value;
            #Will take any numbers we can from the start of value (this is what Mysql does when not in strict mode)
            $value =~ s/^(\d+).*$/$1/;
            # FFS... $self doesn't have session
            #$self->{session}->get_repository->log("MetaField::".$self->get_type." - Trunating value as Non integer found ($ov => $value) ");
            print STDERR "MetaField::".$self->get_type." - Truncating value as Non integer found ($ov => $value) \n";
        }
        return $self->SUPER::set_value($object, $value);
    }
}
