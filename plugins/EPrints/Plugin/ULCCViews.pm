package EPrints::Plugin::ULCCViews;
use strict;
our @ISA = qw/ EPrints::Plugin /;

#override some incongruities in the Views gen code
#specifically to fix the bits that use only the render 
#subs from the *first* menu field. In most cases there 
#is no issue and the value is returned. In *some* cases 
#it is necessary to call the render subs for for each 
#specific field. Loops are added to allow this to happen

package EPrints::Update::Views;

no warnings 'redefine';

sub group_by_n_chars
{
	my( $repo, $menu, $menu_fields, $values, $n ) = @_;

	my $sections = {};
	foreach my $value ( @{$values} )
	{
		#This screws up custom renderng for everything but the first menu_field
#		$v = $repo->xhtml->to_text_dump(
#				$menu_fields->[0]->render_single_value( $repo, $value) );
		my $v;
		for my $field (@{$menu_fields}){
			$v = $repo->xhtml->to_text_dump(
				$field->render_single_value( $repo, $value) );
			last if($v ne $value);
		}
		###########################################################################

		# lose everything not a letter or number
		$v =~ s/\P{Alnum}+//g;
	
		my $start = uc substr( $v, 0, $n );
		$start = "?" if( $start eq "" );	

		push @{$sections->{$start}}, $value;
	}

	return $sections;
}

sub render_menu
{
	my( $repo, $menu, $sizes, $values, $fields, $has_submenu, $view ) = @_;

	if( scalar @{$values} == 0 )
	{
		if( !$repo->get_lang()->has_phrase( "Update/Views:no_items" ) )
		{
			return $repo->make_doc_fragment;
		}
		return $repo->html_phrase( "Update/Views:no_items" );
	}

	my( $cols, $col_len ) = get_cols_for_menu( $menu, scalar @{$values} );
	
	my $add_ul;
	my $col_n = 0;
	my $f = $repo->make_doc_fragment;
	my $tr;

	if( $cols > 1 )
	{
		my $table = $repo->make_element( "table", cellpadding=>"0", cellspacing=>"0", border=>"0", class=>"ep_view_cols ep_view_cols_$cols" );
		$tr = $repo->make_element( "tr" );
		$table->appendChild( $tr );	
		$f->appendChild( $table );
	}
	else
	{
		$add_ul = $repo->make_element( "ul" );
		$f->appendChild( $add_ul );	
	}

	my $ds = $view->dataset;

	for( my $i=0; $i<@{$values}; ++$i )
	{
		if( $cols>1 && $i % $col_len == 0 )
		{
			++$col_n;
			my $td = $repo->make_element( "td", valign=>"top", class=>"ep_view_col ep_view_col_".$col_n );
			$add_ul = $repo->make_element( "ul" );
			$td->appendChild( $add_ul );	
			$tr->appendChild( $td );	
		}
		my $value = $values->[$i];
		my $size = 0;
		my $id = $fields->[0]->get_id_from_value( $repo, $value );
		if( defined $sizes && defined $sizes->{$id} )
		{
			$size = $sizes->{$id};
		}

		next if( $menu->{hideempty} && $size == 0 );

		my $fileid = $fields->[0]->get_id_from_value( $repo, $value );

		my $li = $repo->make_element( "li" );

		#This screws up custom renderng for everything but the first menu_field
#       my $xhtml_value = $fields->[0]->get_value_label( $repo, $value );
		my $xhtml_value;
		for my $field (@{$fields}){
			$xhtml_value = $field->get_value_label( $repo, $value );
			last if(defined $value && EPrints::XML::to_string($xhtml_value) ne $value);
		}
		###################################################################

		my $null_phrase_id = "viewnull_".$ds->base_id()."_".$view->{id};
		if( !EPrints::Utils::is_set( $value ) && $repo->get_lang()->has_phrase($null_phrase_id) )
		{
			$xhtml_value = $repo->html_phrase( $null_phrase_id );
		}

		if( defined $sizes && (!defined $sizes->{$fileid} || $sizes->{$fileid} == 0 ))
		{
			$li->appendChild( $xhtml_value );
		}
		else
		{
			my $link = EPrints::Utils::escape_filename( $fileid );
			if( $has_submenu ) { $link .= '/'; } else { $link .= '.html'; }
			my $a = $repo->render_link( $link );
			$a->appendChild( $xhtml_value );
			$li->appendChild( $a );
		}

		if( defined $sizes && defined $sizes->{$fileid} )
		{
			$li->appendChild( $repo->make_text( " (".$sizes->{$fileid}.")" ) );
		}
		$add_ul->appendChild( $li );
	}
	while( $cols > 1 && $col_n < $cols )
	{
		++$col_n;
		my $td = $repo->make_element( "td", valign=>"top", class=>"ep_view_col ep_view_col_".$col_n );
		$tr->appendChild( $td );	
	}

	return $f;
}

#NB This will need to be kept in parity with the declaration in EPrints::Update::Views
#It should be a config item (eg default max_items), but there are issues if people get 
#happy making super massive list pages. It is all round a bit shonkily implemented in 
#the original code but hey ho
my $MAX_ITEMS = 2000;

sub update_view_list
{
	my( $repo, $target, $langid, $view, $path_values, %opts ) = @_;

	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $menus_fields = $view->menus_fields;
	my $menu_level = scalar @{$path_values};

	# update_view_list must be a leaf node
	if( $menu_level != scalar @{$menus_fields} )
	{
		return;
	}

	# get all of the items for this level
	my $filters = $view->get_filters( $path_values, 1 ); # EXact

	my $ds = $view->dataset;

	my $max_items = $view->{max_items};
	$max_items = $repo->config("browse_views_max_items") if !defined $max_items;
	$max_items = $MAX_ITEMS if !defined $max_items;

	my $list = $ds->search(
		custom_order=>$view->{order},
		satisfy_all=>1,
		filters=>$filters,
		($max_items > 0 ? (limit => $max_items+1) : ()),
	);

	my $count = $list->count;

	# construct the export and navigation bars, which are common to all "alt_views"
	my $menu_fields = $menus_fields->[$#$path_values];

	my $nav_sizes = $opts{sizes};
	if( !defined $nav_sizes && $menu_fields->[0]->isa( "EPrints::MetaField::Subject" ) )
	{
		$nav_sizes = $view->fieldlist_sizes( $path_values, $#$path_values );
	}
	$nav_sizes = {} if !defined $nav_sizes;

	# nothing to show at this level or anywhere below a subject tree
	return if $count == 0 && !scalar(keys(%$nav_sizes));

	my $export_bar = render_export_bar( $repo, $view, $path_values );

	my $navigation_aids = render_navigation_aids( $repo, $path_values, $view, "list",
		export_bar => $xml->clone( $export_bar ),
		sizes => $nav_sizes,
	);

	# hit the limit
	if( $max_items && $count > $max_items )
	{
		$repo->log( "Browse view $view->{id} ($target) contains more than $max_items and has not been rendered.");

		my $PAGE = $xml->create_element( "div",
			class => "ep_view_page ep_view_page_view_$view->{id}"
		);
		$PAGE->appendChild( $navigation_aids );
		$PAGE->appendChild( $repo->html_phrase( "bin/generate_views:max_items",
			n => $xml->create_text_node( $count ),
			max => $xml->create_text_node( $max_items ),
		) );
		output_files( $repo,
			"$target.page" => $PAGE,
		);
		return $target;
	}

	# Timestamp div
	my $time_div;
	if( !$view->{notimestamp} )
	{
		$time_div = $repo->html_phrase(
			"bin/generate_views:timestamp",
			time=>$xml->create_text_node( EPrints::Time::human_time() ) );
	}
	else
	{
		$time_div = $xml->create_document_fragment;
	}

	# modes = first_letter, first_value, all_values (default)
	my $alt_views = $view->{variations};
	if( !defined $alt_views )
	{
		$alt_views = [ 'DEFAULT' ];
	}

	my @items = $list->get_records;

	my @files = ();
	my $first_view = 1;	
	ALTVIEWS: foreach my $alt_view ( @{$alt_views} )
	{
		my( $fieldname, $options ) = split( ";", $alt_view );
		my $opts = get_view_opts( $options, $fieldname );

		my $page_file_name = "$target.".$opts->{"filename"};
		if( $first_view ) { $page_file_name = $target; }

		push @files, $page_file_name;

		my $need_path = $page_file_name;
		$need_path =~ s/\/[^\/]*$//;
		EPrints::Platform::mkdir( $need_path );

		my $title;
		my $phrase_id = "viewtitle_".$ds->base_id()."_".$view->{id}."_list";
		my $null_phrase_id = "viewnull_".$ds->base_id()."_".$view->{id};

		my %files;

		if( $repo->get_lang()->has_phrase( $phrase_id, $repo ) )
		{
			my %o = ();
			for( my $i = 0; $i < scalar( @{$path_values} ); ++$i )
			{
				my $menu_fields = $menus_fields->[$i];
				my $value = $path_values->[$i];
				#This screws up custom renderng for everything but the first menu_field
				#$o{"value".($i+1)} = $menu_fields->[0]->render_single_value( $repo, $value);
				for my $field (@{$menu_fields}){
					my $v = $field->render_single_value( $repo, $value);
					$o{"value".($i+1)} = $v;
 					last if(defined $value && EPrints::XML::to_string($v) ne $value);
				}
				###########################################################################

				if( !EPrints::Utils::is_set( $value ) && $repo->get_lang()->has_phrase($null_phrase_id) )
				{
					$o{"value".($i+1)} = $repo->html_phrase( $null_phrase_id );
				}
			}		
			my $grouping_phrase_id = "viewgroup_".$ds->base_id()."_".$view->{id}."_".$opts->{filename};
			if( $repo->get_lang()->has_phrase( $grouping_phrase_id, $repo ) )
			{
				$o{"grouping"} = $repo->html_phrase( $grouping_phrase_id );
			}
			elsif( $fieldname eq "DEFAULT" )
			{
				$o{"grouping"} = $repo->html_phrase( "Update/Views:no_grouping_title" );
			}	
			else
			{
				my $gfield = $ds->get_field( $fieldname );
				$o{"grouping"} = $gfield->render_name( $repo );
			}

			$title = $repo->html_phrase( $phrase_id, %o );
		}
	
		if( !defined $title )
		{
			$title = $repo->html_phrase(
				"bin/generate_views:indextitle",
				viewname=>$view->render_name,
			);
		}


		# This writes the title including HTML tags
		$files{"$page_file_name.title"} = $title;

		# This writes the title with HTML tags stripped out.
		$files{"$page_file_name.title.textonly"} = $title;

		if( defined $view->{template} )
		{
			$files{"$page_file_name.template"} = $xml->create_text_node( $view->{template} );
		}

		$files{"$page_file_name.export"} = $export_bar;

		my $PAGE = $files{"$page_file_name.page"} = $xml->create_document_fragment;
		my $INCLUDE = $files{"$page_file_name.include"} = $xml->create_document_fragment;

		$PAGE->appendChild( $xml->clone( $navigation_aids ) );
		
		$PAGE = $PAGE->appendChild( $xml->create_element( "div",
			class => "ep_view_page ep_view_page_view_$view->{id}"
		) );
		$INCLUDE = $INCLUDE->appendChild( $xml->create_element( "div",
			class => "ep_view_page ep_view_page_view_$view->{id}"
		) );

		# Render links to alternate groupings
		if( scalar @{$alt_views} > 1 && $count )
		{
			my $groups = $repo->make_doc_fragment;
			my $first = 1;
			foreach my $alt_view2 ( @{$alt_views} )
			{
				my( $fieldname2, $options2 ) = split( /;/, $alt_view2 );
				my $opts2 = get_view_opts( $options2,$fieldname2 );

				my $link_name = join '/', $view->escape_path_values( @$path_values );
				if( !$first ) { $link_name .= ".".$opts2->{"filename"} }

				if( !$first )
				{
					$groups->appendChild( $repo->html_phrase( "Update/Views:group_seperator" ) );
				}

				my $group;
				my $phrase_id = "viewgroup_".$ds->base_id()."_".$view->{id}."_".$opts2->{filename};
				if( $repo->get_lang()->has_phrase( $phrase_id, $repo ) )
				{
					$group = $repo->html_phrase( $phrase_id );
				}
				elsif( $fieldname2 eq "DEFAULT" )
				{
					$group = $repo->html_phrase( "Update/Views:no_grouping" );
				}
				else
				{
					$group = $ds->get_field( $fieldname2 )->render_name( $repo );
				}
				
				if( $opts->{filename} eq $opts2->{filename} )
				{
					$group = $repo->html_phrase( "Update/Views:current_group", group=>$group );
				}
				else
				{
					$link_name =~ /([^\/]+)$/;
					my $link = $repo->render_link( "$1.html" );
					$link->appendChild( $group );
					$group = $link;
				}
		
				$groups->appendChild( $group );

				$first = 0;
			}

			$PAGE->appendChild( $repo->html_phrase( "Update/Views:group_by", groups=>$groups ) );
		}

		# Intro phrase, if any 
		my $intro_phrase_id =
			"viewintro_".$view->{id}.join('', map { "/$_" } $view->escape_path_values( @$path_values ));
		my $intro;
		if( $repo->get_lang()->has_phrase( $intro_phrase_id, $repo ) )
		{
			$intro = $repo->html_phrase( $intro_phrase_id );
		}
		else
		{
			$intro = $xml->create_document_fragment;
		}

		# Number of items div.
		my $count_div;
		if( !$view->{nocount} )
		{
			my $phraseid = "bin/generate_views:blurb";
			if( $menus_fields->[-1]->[0]->isa( "EPrints::MetaField::Subject" ) )
			{
				$phraseid = "bin/generate_views:subject_blurb";
			}
			$count_div = $repo->html_phrase(
				$phraseid,
				n=>$xml->create_text_node( $count ) );
		}
		else
		{
			$count_div = $xml->create_document_fragment;
		}


		if( defined $opts->{render_fn} )
		{
			my $block = $repo->call( $opts->{render_fn}, 
					$repo,
					\@items,
					$view,
					$path_values,
					$opts->{filename} );
			$block = $xml->parse_string( $block )
				if !ref( $block );

			$PAGE->appendChild( $xml->clone( $intro ) );
			$INCLUDE->appendChild( $xml->clone( $intro ) );

			$PAGE->appendChild( $view->render_count( $count ) );
			$INCLUDE->appendChild( $view->render_count( $count ) );

			$PAGE->appendChild( $xml->clone( $block ) );
			$INCLUDE->appendChild( $block );

			$PAGE->appendChild( $xml->clone( $time_div ) );
			$INCLUDE->appendChild( $xml->clone( $time_div ) );

			$first_view = 0;

			output_files( $repo, %files );
			next ALTVIEWS;
		}


		# If this grouping is "DEFAULT" then there is no actual grouping-- easy!
		if( $fieldname eq "DEFAULT" ) 
		{
			my $block = render_array_of_eprints( $repo, $view, \@items );

			$PAGE->appendChild( $xml->clone( $intro ) );
			$INCLUDE->appendChild( $xml->clone( $intro ) );

			$PAGE->appendChild( $view->render_count( $count ) );
			$INCLUDE->appendChild( $view->render_count( $count ) );

			$PAGE->appendChild( $xml->clone( $block ) );
			$INCLUDE->appendChild( $block );

			$PAGE->appendChild( $xml->clone( $time_div ) );
			$INCLUDE->appendChild( $xml->clone( $time_div ) );

			$first_view = 0;
			output_files( $repo, %files );
			next ALTVIEWS;
		}

		my $data = group_items( $repo, \@items, $ds->field( $fieldname ), $opts );

		my $first = 1;
		my $jumps = $repo->make_doc_fragment;
		my $total = 0;
		my $maxsize = 1;
		foreach my $group ( @{$data} )
		{
			my( $code, $heading, $items ) = @{$group};
			my $n = scalar @$items;
			$total += $n;
			if( $n > $maxsize ) { $maxsize = $n; }
		}
		my $range;
		if( $opts->{cloud} )
		{
			$range = $opts->{cloudmax} - $opts->{cloudmin};
		}
		foreach my $group ( @{$data} )
		{
			my( $code, $heading, $items ) = @{$group};
			if( scalar @$items == 0 )
			{
				print STDERR "ODD: $code has no items\n";
				next;
			}
	
			if( !$first )
			{
				if( $opts->{"no_seperator"} ) 
				{
					$jumps->appendChild( $repo->make_text( " " ) );
				}
				else
				{
					$jumps->appendChild( $repo->html_phrase( "Update/Views:jump_seperator" ) );
				}
			}

			my $link = $repo->render_link( "#group_".EPrints::Utils::escape_filename( $code ) );
			$link->appendChild( $repo->clone_for_me($heading,1) );
			if( $opts->{cloud} )
			{
				my $size = int( $range * ( log(1+scalar @$items ) / log(1+$maxsize) ) ) + $opts->{cloudmin};
				my $span = $repo->make_element( "span", style=>"font-size: $size\%" );
				$span->appendChild( $link );
				$jumps->appendChild( $span );
			}
			else
			{
				$jumps->appendChild( $link );
			}

			$first = 0;
		}

		if( $total > 0 )
		{
			# css for your convenience
			my $jumpmenu = $xml->create_element( "div",
				class => "ep_view_jump ep_view_$view->{id}_${fieldname}_jump"
			);
			if( $opts->{"jump"} eq "plain" ) 
			{
				$jumpmenu->appendChild( $jumps );
			}
			elsif( $opts->{"jump"} eq "default" )
			{
				$jumpmenu->appendChild( $repo->html_phrase(
					"Update/Views:jump_to",
					jumps=>$jumps ) );
			}

			$PAGE->appendChild( $xml->clone( $jumpmenu ) );
			$INCLUDE->appendChild( $jumpmenu );
		}

		$PAGE->appendChild( $xml->clone( $intro ) );
		$INCLUDE->appendChild( $xml->clone( $intro ) );

		$PAGE->appendChild( $view->render_count( $total ) );
		$INCLUDE->appendChild( $view->render_count( $total ) );

		foreach my $group ( @{$data} )
		{
			my( $code, $heading, $items ) = @{$group};

			my $link = $xml->create_element( "a",
				name => "group_".EPrints::Utils::escape_filename( $code )
			);
			my $h2 = $xml->create_element( "h2" );
			$h2->appendChild( $heading );
			my $block = render_array_of_eprints( $repo, $view, $items );

			$PAGE->appendChild( $xml->clone( $link ) );
			$INCLUDE->appendChild( $link );
		
			$PAGE->appendChild( $xml->clone( $h2 ) );
			$INCLUDE->appendChild( $h2 );

			$PAGE->appendChild( $xml->clone( $block ) );
			$INCLUDE->appendChild( $block );
		}

		$PAGE->appendChild( $xml->clone( $time_div ) );
		$INCLUDE->appendChild( $xml->clone( $time_div ) );

		$first_view = 0;
		output_files( $repo, %files );
	}

	return $target;
}

1;
