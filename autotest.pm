package VCS::Settings::autotest;
use strict;

use VCS::Users::login;
use VCS::Users::register;
use VCS::Reports::docs;
use VCS::DHL;
use VCS::Vars;

use Data::Dumper;
use Storable;
use File::Find qw(find);

sub new
{
	my ($class,$pclass,$vars) = @_;
	my $self = bless {}, $pclass;
	$self->{'VCS::Vars'} = $vars;
	return $self;
}

sub getContent 
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};

	if (($vars->get_session->{'login'} ne '') && ($id eq 'index')) {
		$self->autotest($task,$id,$template);

	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'captcha_h')) {
		$self->captcha_hack($task,$id,$template);

	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'test_and_clean')) {
		$self->test_and_clean($task,$id,$template);

	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'langreq')) {
		$self->langreq($task,$id,$template);

	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'sqltest')) {
		$self->sql_test($task,$id,$template);
		
	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'modultest')) {
		$self->modultest($task,$id,$template);

	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'get_aid')) {
		$self->get_aid($task,$id,$template);

	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'test_and_clean_doc')) {
		$self->test_and_clean_doc($task,$id,$template);

	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'test_syntax')) {
		$self->test_syntax($task,$id,$template);

	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'test_update')) {
		$self->test_update($task,$id,$template);

	} else {
		# redirect
		$vars->get_system->redirect($vars->getform('fullhost').'/admin/login.htm');
	}

	return 1;
}

sub autotest
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	$vars->get_system->pheader($vars);
	my $tvars = {
		'langreq'  => sub { return $vars->getLangSesVar(@_) },
		'vars' =>	{
			'lang' => $vars->{'lang'},
			'page_title'  => 'Самотестирование'
					},
		'form' =>	{
			'action' => $vars->getform('action')
					},
		'session'	=> $vars->get_session,
		'menu'		=> $vars->admfunc->get_menu($vars)
	};
	$template->process('autotest.tt2',$tvars);
}

sub captcha_hack
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	my $config = $vars->getConfig('captcha');

	my $err = 0;
	
	my $code = $vars->getparam('code') || '';
	
	$err = 1 if (!$code);
	
	open my $f_captcha, '>>', $config->{'data_folder'} . 'codes.txt' or $err = 1;
	print $f_captcha time() . '::' . $code;
	close $f_captcha;
	
	$vars->get_system->pheader($vars);	
	print "ok" if !$err;
	print "captcha error" if $err;
}

sub test_and_clean
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};

	my $err = 0;
	
	my ($id_app) = $vars->db->sel1("select ID from Appointments where PassNum = '0808AUTOTEST'");
	my ($id_app_data) = $vars->db->sel1("select ID from AppData where PassNum = '0909AUTOTEST'");
	
	$err = !(($id_app != 0) and ($id_app_data != 0));
	
	$vars->db->query("delete from Appointments where PassNum = '0808AUTOTEST'", {});
	$vars->db->query("delete from AppData where PassNum = '0909AUTOTEST'", {});
	
	$vars->get_system->pheader($vars);	
	print "ok" if !$err;
	print "db error" if $err;
}

my $voc_cont = {};
my $voc;

sub langreq
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};

	my $path = '/usr/local/www/data/htdocs/vcs/';
	my $vocab = '/usr/local/www/data/htdocs/vcs/tmp/vocabulary.dat';
	
	$vars->get_system->pheader($vars);
	$voc = retrieve($vocab);
	
	find( \&search_all_folder, $path );
}

sub search_all_folder {
	chomp $_;
	return if $_ eq '.' or $_ eq '..';
	read_files($_) if (-f);
	}

sub read_files {
	my $filename = shift;
	
	if ((($filename =~ /\.pm$/i) or ($filename =~ /\.tt2$/i))
			and (!($filename =~ /^config/i))
			and (!($filename =~ /^resources\.pm$/i)) ) {
		
		open my $file_tmp, '<', $filename;
		my $ch = 0;
		my $ch2 = 0;
		while (<$file_tmp>) {
			if ( (/[АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя]/) 
				and (!/(langreq|getLangSesVar|getGLangVar|getLangVar)/i) and (!/#/) ) {
					$ch++;
				}
			if (/(langreq|getLangVar)\s?\(\s?\'([^\']+)\'\s?\)/i) {
				unless (exists($voc->{$2}->{'en'})) {
					unless (exists($voc_cont->{$2})) {
						$voc_cont->{$2} = '1';
						$ch2++;
				} } } }
		close $file_tmp;
		print '\\n'.$filename." (" if $ch or $ch2;
		print "нет langreq: $ch" if $ch; 
		print "/" if $ch and $ch2; 
		print "нет перевода: $ch2" if $ch2;
		print ") " if $ch or $ch2;
		}
	}

my $tables = {};

sub sql_test {
# //////////////////////////////////////////////////
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	my $path = '/usr/local/www/data/htdocs/vcs/lib';
	my $sql_r = '';
	my $sql_num = 0;

	my $db_hash = get_db_hash($vars);
	
	find( \&search_all_query, $path );
	
	for my $file (keys %$tables) {
		for my $tab (keys %{$tables->{$file}}) {
			for my $col (keys %{$tables->{$file}->{$tab}}) {
				$_ =~ s/('|`|\)|\()//g for ($col, $tab);
				$_ =~ s/^(\s|-)+//g for ($col, $tab);
				my $tab2 = lc($tab);
				my $col2 = lc($col);
				$col2 =~ s/^[^\.]+\.//g if $col2 =~ /\./;
				$sql_r .= "$tab - $col ($file)" . '\n' if !exists($db_hash->{$tab2}->{$col2}); 
				$sql_num++;
		}}}
		
	$vars->get_system->pheader($vars);
	if ($sql_r) { print $sql_r; } else { print "ok|$sql_num"; };
	}

sub get_db_hash {
	my $vars = shift;
	my $hash = {};
	
	my $rws = $vars->db->selall("show tables");
	for my $row (@$rws) {
		my $rws2 = $vars->db->selall("select column_name from information_schema.columns ".
				"where table_name = '" . $row->[0] . "';");
   		for my $row2 (@$rws2) {	
   			$row->[0] = lc($row->[0]);
   			$row2->[0] = lc($row2->[0]);
   			$hash->{$row->[0]}->{$row2->[0]} = 1; }
		}
	return $hash;
	}
	
sub search_all_query {
	chomp $_;
	return if $_ eq '.' or $_ eq '..';
	query_search_files($_) if (-f);
	}

sub query_search_files {
	my ($filename) = @_;
	my @sql = ();
	my $conti = 0;
	my @sql_insert = ();
	my $conti_insert = 0;
	my @sql_update = ();
	my $conti_update = 0;
	
	return if $filename =~ /autotest/i;
	
	open TMP, '<', $filename;

	while(<TMP>) {
		next if /errstr/i;
		next if /^\s*#/;
			
		if (((/\$vars->db->/i) and ((/SELECT/i) or (/INSERT.*?\(.*?\).*?VALUES/i) or (/UPDATE.*?SET.*?WHERE/i))) 
					or $conti or $conti_insert or $conti_update)  {;
			chomp;
			s/(^\s+|\s+$)//g;
					
			push(@sql, $_) if !$conti and /SELECT/i;
			push(@sql_insert, $_) if !$conti_insert and /INSERT.*?\(.*?\).*?VALUES/i;
			push(@sql_update, $_) if !$conti_update and /UPDATE.*?SET.*?WHERE/i;

			$sql[-1] .= " $_" if $conti;
			$sql_insert[-1] .= " $_" if $conti_insert;
			$sql_update[-1] .= " $_" if $conti_update;

			$conti = 0 if $conti and /;/;
			$conti_insert = 0 if $conti_insert and /;/;
			$conti_update = 0 if $conti_update and /;/;
			
			$conti = 1 if !/;/ and /SELECT/i; 
			$conti_insert = 1 if !/;/ and /INSERT.*?\(.*?\).*?VALUES/i;
			$conti_update = 1 if !/;/ and /UPDATE.*?SET.*?WHERE/i;
			}				
		}
	close TMP;

	for(@sql) {
		my $current_t;
		s/\sas\s[^\s,]+(\s|,)/$1/gi;
		s/('|")\s*\.\s*('|")//gix;
		s/SELECT\s.*?('|")\s*[^'"]+('|").*?\sFROM\s//gi;
		s/NOW\(\)//gi;
		s/COUNT\s?\(\d+\)//gi;
		s/(MAX|MIN|COUNT|SUM|DATE_FORMAT|TIMESTAMP|DATEDIFF)\(([^\)]*)\)/$2/gi;
		s/DISTINCT//gi;
		s/\(\)//g;	
		s/IF\([^\)]+\)//gi;
	
		next if /FROM.*JOIN/i;
		next if /FROM.*SELECT/i;
		next if /FROM.*?,.*?WHERE/i;
		next if /information_schema/i;
		next if /last_insert_id/i;
		
		while(/\sFROM\s([^\s]+)\s/i) {
			$current_t = $1; 
	
			while(/SELECT\s*,?\s*([^\s,]+)\s*,?.*?\s*FROM/i) { 
				if (!($1 =~ /\*/)) {
					$tables->{$filename}->{$current_t}->{$1} = '(select)';
					s/SELECT(\s|,)+$1/SELECT /i; }
				else { s/\*//g; }; 
				s/SELECT[\s,]+FROM//gi;
				}
			s/FROM//i;
			}
		} 
	
	for(@sql_insert) {
		s/.*?INSERT//i;
		s/VALUES.+$/VALUES/i;
		s/('|")\..*?\.('|")//gi;
		
		/INTO\s*([^\(\s]+)\s*\(/i;
		my $current_t = $1;
	
		while(/\((\s|,)*([^\)\s,]+)(,|\s|\))*.*VALUES/i) { 
			my $_2 = $2;
			$tables->{$filename}->{$current_t}->{$_2} = '(insert)';
			s/$_2//i; 
			s/\([\s,]*\)\s*VALUES//gi;
			}
		} 	

	for(@sql_update) {
		s/^.*?[^T]UPDATE/UPDATE/i;
		s/WHERE.+$/WHERE/i;
		s/('|")\..*?\.('|")//gi;
		/UPDATE\s*([^\(\s]+)\s*SET/i;
		my $current_t = $1; 

		while(/SET(\s|,)+([^=\s]+)\s*=.*?(\s|,)\s*WHERE/i) { 
			my $_2 = $2;
			$tables->{$filename}->{$current_t}->{$_2} = '(update)';
			s/$_2.*?(\s|,)//i; 
			s/SET[\s,]*WHERE//gi;
			}
		} 	
	
	}

sub get_aid
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};

	my $err = 0;
	
	my ($id_app) = $vars->db->sel1("select ID from Appointments where PassNum = '0808AUTOTEST'");
	my ($id_app_data) = $vars->db->sel1("select ID from AppData where PassNum = '0909AUTOTEST'");
	
	$vars->get_system->pheader($vars);
	if ( ($id_app != 0) && ($id_app_data != 0) ) {
		$err = $vars->db->query("update Appointments set AppDate = curdate() where ID = ?", {}, $id_app);
		print $id_app.'|'.$id_app_data; }
	else {
		print "db error"; };
}

sub test_and_clean_doc
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};

	my $err = 0;
	
	my ($id_app) = $vars->db->sel1("select ID from Appointments where PassNum = '0808AUTOTEST'");
	my ($id_app_data) = $vars->db->sel1("select ID from AppData where PassNum = '0909AUTOTEST'");
	my ($doc_pack) = $vars->db->sel1("select ID from DocPack where PassNum = '101010AUTOTEST'");
	my ($doc_pack_info) = $vars->db->sel1("select ID from DocPackInfo where PackID = ?", $doc_pack);
	
	$err = !(($id_app != 0) and ($id_app_data != 0) and (($doc_pack) != 0) and (($doc_pack_info) != 0));
	
	$vars->db->query("delete from DocPack where PassNum = '101010AUTOTEST'", {});
	$vars->db->query("delete from DocPackInfo where PackID = ?", {}, $doc_pack);
	$vars->db->query("delete from DocPackList where PassNum = '0909AUTOTEST'");
	
	$vars->get_system->pheader($vars);	
	print "ok" if !$err;
	print "db error" if $err;
}

my $synax_num = 0;
my $syntax_err = '';

sub test_syntax
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	
	my $path = '/usr/local/www/data/htdocs/vcs/lib/';
	
	$vars->get_system->pheader($vars);
	
	find( \&syntax_all_folder, $path );
	
	$vars->get_system->pheader($vars);
	print "ok|$synax_num" if !$syntax_err;
	print $syntax_err if $syntax_err;
}

sub syntax_all_folder {
	chomp $_;
	return if $_ eq '.' or $_ eq '..';
	syntax_files($_) if (-f);
	}

sub syntax_files {
	my $filename = shift;
	$synax_num++;
	
	if (($filename =~ /\.pm$/i) or ($filename =~ /\.pl2$/i)) {
		if (!(`perl -c -I $filename 2>&1` =~ /syntax OK/)) {		
			$syntax_err .= '\\n'.$filename." (ошибки синтаксиса)";
			}
		}
	}

sub test_update
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	
	my $err = '';
	
	my $last_rate = $vars->db->selallkeys("select p.BranchID as R_id, max(p.RDate) as R_date, l.ConcilR ".
				"from Branches b join PriceRate p on b.ID = p.BranchID ".
				"join PriceList l on p.ID = l.RateID where VisaID = 1 group by p.BranchID");
	
	my ($day, $month, $year) = (localtime)[3..5];
	$month++; 
	$year += 1900;
	for($day, $month) { $_ = "0$_" if ($_ < 10) && (!/^0/); };
	
	my $date_current = "$year-$month-$day";
	my $consil_current = fast_calc_consil("$day.$month.$year");
	$err .= 'недоступен API ЦБ РФ\\n' if !$consil_current;
	
	for my $l_rate(@$last_rate) {
		$err .= 'cтарый прайслист ('.$l_rate->{R_id}.'/'.$l_rate->{R_date}.')\\n'
			if $l_rate->{R_date} lt $date_current; }
	
	for my $l_rate(@$last_rate) {	
		$err .= 'отличие курса у центра '.$l_rate->{R_id}.' ('.$l_rate->{ConcilR}.'<=>'.$consil_current.')\\n'
			if ($l_rate->{ConcilR}*0.95 < $consil_current) or ($l_rate->{ConcilR}*1.05 > $consil_current); }
	

	$vars->get_system->pheader($vars);
	print "ok" if !$err;
	print $err if $err;
}

sub fast_calc_consil
{
	my $c_date = shift;

	use LWP::Simple;
	use XML::Simple;
	
	my $parse = get 'http://www.cbr.ru/scripts/XML_daily.asp?date_req='.$c_date;
	$parse=~s/windows-1251/UTF-8/;
	return 0 if (!$parse);
	
	my $parse_xml = XMLin($parse);
	my $parse_eur = $parse_xml->{'Valute'};
	my $euro = 0;
	for my $par(@$parse_eur) {
		$euro = $par->{'Value'} if $par->{'CharCode'} eq 'EUR'; };
	$euro =~ s/,/\./gix;
	return 0 if (!$euro);
	
	$euro *= 35;
	return $euro;
}
	
sub modultest
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	my $vars_for_vars = new VCS::Vars(qw( VCS::Config VCS::List VCS::System ));

	my $err = '';
	my $test_num = 0;
	
	my $ru_utf_1 = 'AАБBВГCДD';
	my $ru_utf_2 = 'EЯёFЮюЙЫE';
	my $ru_utf_3 = 'AАБBВГCДD';
	my $ru_utf_4 = 'EЯёFЮюЙЫE';
	utf8::encode($ru_utf_1);
	utf8::encode($ru_utf_2);
	
	my $tests = [ 
	{ 	'func' 	=> \&VCS::AdminFunc::getPrices,
		'comment' => 'AdminFunc / getPrices',
		'tester' => \&test_hash,
		'test' => { 	1 => [ ['',$vars,1595,1,'01.01.2010'], ['urgent','visa','photosrv'] ],
				2 => [ ['',$vars,1586,1,'01.01.2012'], ['vipsrv','shipnovat','xerox'] ],
				3 => [ ['',$vars,1178,1,'01.01.2014'], ['shipping','printsrv','anketasrv'] ], },
	},{ 	'func' => \&VCS::AdminFunc::get_branch,
		'comment' => 'AdminFunc / get_branch',
		'tester' => \&test_hash,
		'test' => { 	1 => [ ['',$vars,1], ['calcInsurance','CollectDate','isPrepayedAppointment'] ], 
				2 => [ ['',$vars,29], ['Embassy','persPerDHLPackage','isShippingFree'] ],
				3 => [ ['',$vars,39], ['cdSimpl','CTemplate','Timezone'] ], },
	},{ 	'func' => \&VCS::AdminFunc::getAgrNumber,
		'comment' => 'AdminFunc / getAgrNumber',
		'tester' => \&test_line,
		'test' => { 	1 => [ ['',$vars,1,'01.01.2010'], '0100000101.01.2010' ],
				2 => [ ['',$vars,29,'01.01.2012'], '2900000101.01.2012' ],
				3 => [ ['',$vars,39,'01.01.2014'],'3900000101.01.2014' ], },
	},{ 	'func' => \&VCS::AdminFunc::getRate,
		'comment' => 'AdminFunc / getRate',
		'tester' => \&test_line,
		'test' => { 	1 => [ ['',$vars,'RUR','31.12.2014',1], '1595' ],
				2 => [ ['',$vars,'RUR','21.10.2014',29], '1604' ],
				3 => [ ['',$vars,'RUR','20.10.2015',39], '1600' ], },
	},{ 	'func' => \&VCS::AdminFunc::sum_to_russtr,
		'comment' => 'AdminFunc / sum_to_russtr',
		'tester' => \&test_line,
		'test' => { 	1 => [ ['','RUR','10000.00'], 'ДЕСЯТЬ ТЫСЯЧ 00 КОПЕЕК' ],
				2 => [ ['','EUR','33023.01'], 'ТРИДЦАТЬ ТРИ ТЫСЯЧИ ДВАДЦАТЬ ТРИ ЕВРО 01 ЕВРОЦЕНТ' ],
				3 => [ ['','RUR','75862.21'], 'СЕМЬДЕСЯТ ПЯТЬ ТЫСЯЧ ВОСЕМЬСОТ ШЕСТЬДЕСЯТ ДВА РУБЛЯ 21 КОПЕЙКА' ], },
	},{ 	'func' => \&VCS::AdminFunc::get_pre_servicecode,
		'comment' => 'AdminFunc / get_pre_servicecode',
		'tester' => \&test_line,
		'test' => { 	1 => [ ['',$vars,'visa',{'center'=>1,'urgent'=>1,'jurid'=>1,'ptype'=>1} ], 'ITA00122' ],
				2 => [ ['',$vars,'visa',{'center'=>14, 'urgent'=>0,'jurid'=>0,'ptype'=>2}], 'ITA12201' ],
				3 => [ ['',$vars,'concilc',{'center'=>20,'urgent'=>1,'jurid'=>0,'ptype'=>1}], 'ITA19601' ], },
	},{ 	'func' => \&VCS::AdminFunc::get_currencies,
		'comment' => 'AdminFunc / get_currencies',
		'tester' => \&test_hash,
		'test' => { 	1 => [ ['',$vars], [ 'RUR' ] ], }, 
	
	},{ 	'func' => \&VCS::List::getList,
		'comment' => 'List / getList',
		'tester' => \&test_hash,
		'test' => { 	1 => [ [ 'null' ], [ 'gender', 'days', 'doc_status' ] ], },
	
	},{ 	'func' => \&VCS::Config::getConfig,
		'comment' => 'Config / getConfig',
		'tester' => \&test_hash,
		'test' => { 	1 => [ [ 'null' ], [ 'general', 'dhl', 'sms_http', 'authlist', 'db', 'templates' ] ], },
	
	},{ 	'func' => \&VCS::Vars::getCaptchaErr,
		'comment' => 'Vars / getCaptchaErr',
		'tester' => \&test_line,
		'test' => { 	1 => [ ['', '0' ], 'Файл не найден' ],
				2 => [ ['', '-1' ], 'Время действия кода истекло' ],
				3 => [ ['', '-3' ], 'Неверно указан код на изображении' ], },
	},{ 	'func' => \&VCS::Vars::getConfig,
		'comment' => 'Vars / getConfig',
		'tester' => \&test_hash,
		'test' => { 	1 => [ [ $vars_for_vars, 'dhl' ], [ 'PersonName', 'CompanyAddress', 'CompanyName' ] ],
				2 => [ [ $vars_for_vars, 'templates' ], [ 'report', 'settings', 'nist' ] ],
				3 => [ [ $vars_for_vars, 'general' ], [ 'base_currency', 'files_delivery', 'pers_data_agreem' ] ], },
	},{ 	'func' => \&VCS::Vars::getList,
		'comment' => 'Vars / getList',
		'tester' => \&test_hash,
		'test' => { 	1 => [ [ $vars_for_vars, 'languages' ], [ 'ru', 'en', 'it' ] ],
				2 => [ [ $vars_for_vars, 'app_status' ], [ 1, 3, 5 ] ],
				3 => [ [ $vars_for_vars, 'service_codes' ], [ '01VP01', '11VP01', '15VP02' ] ], },
	},{ 	'func' => \&VCS::Vars::getListValue,
		'comment' => 'Vars / getListValue',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ $vars_for_vars, 'days', 4 ], 'Thursday' ],
				2 => [ [ $vars_for_vars, 'short_currency', 'RUR' ], 'руб.' ],
				3 => [ [ $vars_for_vars, 'service_codes', '01VP03' ], 'ITA00201' ], },
	},{ 	'func' => \&VCS::Vars::getparam,
		'comment' => 'Vars / getparam',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ $vars, 'test_param' ], 'test_is_ok' ],
				2 => [ [ $vars, 'id' ], 'modultest' ],
				3 => [ [ $vars, 'task' ], 'autotest' ], },
	},{ 	'func' => \&VCS::Vars::getGLangVar,
		'comment' => 'Vars / getGLangVar',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ $vars, 'doc_ready', 'ru' ], 'Документы готовы для получения' ], 
				2 => [ [ $vars, 'payed', 'en' ], 'The agreement has been paid' ],
				3 => [ [  $vars, 'wait_for_payment', 'it' ], 'Pagamento del contratto da effettuare' ], },
	},{ 	'func' => \&VCS::Vars::getLangVar,
		'comment' => 'Vars / getLangVar',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ $vars, 'doc_ready' ], 'Документы готовы для получения' ],
				2 => [ [  $vars, 'payed' ], 'Договор оплачен' ],
				3 => [ [  $vars, 'wait_for_payment' ], 'Ожидается оплата договора' ], },
	},{ 	'func' => \&VCS::Vars::getLangSesVar,
		'comment' => 'Vars / getLangSesVar',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ $vars, 'doc_ready', 'ru' ], 'Документы готовы для получения' ], 
				2 => [ [ $vars, 'payed', 'en' ], 'Договор оплачен' ],
				3 => [ [ $vars, 'wait_for_payment', 'it' ], 'Ожидается оплата договора' ] },
	},{ 	'func' => \&VCS::Vars::getform,
		'comment' => 'Vars / getform',
		'tester' => \&test_line_substr,
		'test' => { 	1 => [ [ $vars, 'fullhost' ], 'http://' ], 
				2 => [ [ $vars, 'action' ], '/autotest/modultest.htm' ] },
	},{ 	'func' => \&VCS::System::RTF_string,
		'comment' => 'System / RTF_string',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', 'ABC', ], '\\u65?\\u66?\\u67?' ], 
				2 => [ [ '', '*/"""__', ], '\\u42?\\u47?\\u34?\\u34?\\u34?\\u95?\\u95?' ] },
	},{ 	'func' => \&VCS::System::encodeurl,
		'comment' => 'System / encodeurl',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', 'http://www.italy-vms.ru', ], 'http%3A%2F%2Fwww.italy-vms.ru' ], 
				2 => [ [ '', 'http://www.estonia-vms.ru', ], 'http%3A%2F%2Fwww.estonia-vms.ru' ] },
	},{ 	'func' => \&VCS::System::decodeurl,
		'comment' => 'System / decodeurl',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', 'http%3A%2F%2Fwww.italy-vms.ru', ], 'http://www.italy-vms.ru' ], 
				2 => [ [ '', 'http%3A%2F%2Fwww.estonia-vms.ru', ], 'http://www.estonia-vms.ru' ] },
	},{ 	'func' => \&VCS::System::cutEmpty,
		'comment' => 'System / cutEmpty',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', '   ABCD       ', ], 'ABCD' ], 
				2 => [ [ '', '&nbsp;&nbsp;EFGH&nbsp;&nbsp;', ], 'EFGH' ] },
	},{ 	'func' => \&VCS::System::is_adult,
		'comment' => 'System / is_adult',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', '25.01.1998', '25.01.2016' ], 1 ], 
				2 => [ [ '', '26.01.1998', '25.01.2016' ], 0 ],
				3 => [ [ '', '25.01.2015', '25.01.2016' ], 0 ], },
	},{ 	'func' => \&VCS::System::is_child,
		'comment' => 'System / is_child',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', '24.01.2010', '25.01.2016' ], 0 ], 
				2 => [ [ '', '26.01.2010', '25.01.2016' ], 1 ],
				3 => [ [ '', '25.01.2016', '25.01.2016' ], 1 ], },
	},{ 	'func' => \&VCS::System::age,
		'comment' => 'System / age',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', '1998-01-25', '2016-01-25' ], 18 ], 
				2 => [ [ '', '1998-01-26', '2016-01-25' ], 17 ],
				3 => [ [ '', '2010-01-26', '2016-01-25' ], 5 ],
				4 => [ [ '', '2010-01-25', '2016-01-25' ], 6 ], },
	},{ 	'func' => \&VCS::System::rus_letters_pass,
		'comment' => 'System / rus_letters_pass',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', $ru_utf_1 ], 'ABCD' ], 
				2 => [ [ '', $ru_utf_2 ], 'EFE' ] },
	},{ 	'func' => \&VCS::System::transliteration,
		'comment' => 'System / transliteration',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', $ru_utf_3 ], 'AABBVGCDD' ], 
				2 => [ [ '', $ru_utf_4 ], 'EYAYOFYUYUIYE' ] },
	},{ 	'func' => \&VCS::System::to_lower_case,
		'comment' => 'System / to_lower_case',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', 'ABCDEFGH' ], 'abcdefgh' ], 
				2 => [ [ '', 'D_E_F_H' ], 'd_e_f_h' ] },
	},{ 	'func' => \&VCS::System::to_upper_case,
		'comment' => 'System / to_upper_case',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', 'abcdefgh' ], 'ABCDEFGH' ], 
				2 => [ [ '', 'd_e_f_h' ], 'D_E_F_H' ] },
	},{ 	'func' => \&VCS::System::to_upper_case_first,
		'comment' => 'System / to_upper_case_first',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', 'abcdefgh' ], 'Abcdefgh' ], 
				2 => [ [ '', 'e_f_h' ], 'E_f_h' ] },
	},{ 	'func' => \&VCS::System::get_fulldate,
		'comment' => 'System / get_fulldate',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', 1453710363 ], '25.01.2016 11:26:03' ], 
				2 => [ [ '', 1403310427 ], '21.06.2014 04:27:07' ] },
	},{ 	'func' => \&VCS::System::now_date,
		'comment' => 'System / now_date',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', 1453710363 ], '2016-01-25' ], 
				2 => [ [ '', 1403310427 ], '2014-06-21' ] },
	},{ 	'func' => \&VCS::System::cmp_date,
		'comment' => 'System / cmp_date',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', '26.01.2016', '2016-01-25' ], -1 ], 
				2 => [ [ '', '2016-01-25', '25.01.2016' ], 0 ],
				3 => [ [ '', '24.01.2016', '2016-01-25' ], 1 ] },
	},{ 	'func' => \&VCS::System::time_to_str,
		'comment' => 'System / time_to_str',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', 56589 ], '15:43' ], 
				2 => [ [ '', 75236 ], '20:53' ] },
	},{ 	'func' => \&VCS::System::str_to_time,
		'comment' => 'System / str_to_time',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', '15:43' ], 56580 ], 
				2 => [ [ '', '20:53' ], 75180 ] },
	},{ 	'func' => \&VCS::System::appnum_to_str,
		'comment' => 'System / appnum_to_str',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', '039201601250001' ], '039/2016/01/25/0001' ], 
				2 => [ [ '', '059201502530002' ], '059/2015/02/53/0002' ] },
	},{ 	'func' => \&VCS::System::dognum_to_str,
		'comment' => 'System / dognum_to_str',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', '29000001123015' ], '29.000001.123015' ], 
				2 => [ [ '', '01000002123015' ], '01.000002.123015' ] },
	},{ 	'func' => \&VCS::System::converttext,
		'comment' => 'System / converttext',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', 'A"B^C<D>E&F' ], 'A&quot;B^C&lt;D&gt;E&F' ], 
				2 => [ [ '', 'A"B^C<D>E&F', 1 ], 'A&quot;B^C&lt;D&gt;E&amp;F' ] },
	},{ 	'func' => \&VCS::System::showHref,
		'comment' => 'System / showHref',
		'tester' => \&test_line_substr,
		'test' => { 	1 => [ [ '', $vars, {1 => 'aa', 2 => 'bb'} ], '/?1=aa&2=bb' ], 
				2 => [ [ '', $vars, {1 => 'aa', 2 => 'bb'}, 1 ], 'http://' ] },
	},{ 	'func' => \&VCS::System::showForm,
		'comment' => 'System / showForm',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', $vars, {1 => 'aa', 2 => 'bb'}, 0, 'name', 1 ], 
					'<form action="/" method="POST" name="name" target="1">'.
					'<input type="hidden" name="1" value="aa"><input type="hidden" '.
					'name="2" value="bb">' ], 
				2 => [ [ '', $vars, {1 => 'aa', 2 => 'bb'}, 1 ], 
					'<form action="/" method="POST" enctype="multipart/form-data">'.
					'<input type="hidden" name="1" value="aa"><input type="hidden" '.
					'name="2" value="bb">' ] },
	},{ 	'func' => \&VCS::System::check_mail_address,
		'comment' => 'System / check_mail_address',
		'tester' => \&test_line,
		'test' => { 	1 => [ [ '', 'email_email.com' ], 0 ], 
				2 => [ [ '', 'email@email' ], 0 ],
				3 => [ [ '', 'email@email.com' ], 1 ],
				4 => [ [ '', 'email@em*ail.com' ], 0 ]	},
	},{ 	'func' => \&VCS::System::get_pages,
		'comment' => 'System / get_pages',
		'tester' => \&test_hash,
		'test' => { 	1 => [ [ '', $vars, 'cms', 'location', 'SELECT Count(*) FROM Users', ['param'] ], 
					[ 'position', 'show', 'pages' ] ], 
				},
	},
	];
	
	for my $test (@$tests) {
		my $err_tmp;
		for(keys %{$test->{test}}) {
			my $tmp_r = &{$test->{func}}(@{$test->{test}->{$_}->[0]});
			$err_tmp = &{$test->{tester}}($tmp_r, $test->{test}->{$_}->[1],$test->{comment}) if !$err_tmp;
			#warn Dumper($tmp_r,$test->{test}->{$_}->[1]);
			$test_num++;
			} 
		$err .= "$err_tmp\\n" if $err_tmp;
		}
	$err =~ s/(^(\s|\n)+|(\s|\n)+$)//g;
	
	$vars->get_system->pheader($vars);	
	print "ok|$test_num" if !$err;
	print $err if $err;
	}

sub test_hash {
	my $test_hash = shift;
	my $pattern_ar = shift;
	my $comment = shift;
	
	my $err = 0;
	
	for (@$pattern_ar) {
		$err = 1 if !exists($test_hash->{$_}); }
	
	if ($err) {
		return $comment; }
	else {	return '' };
	}

sub test_line {
	if (shift ne shift) { return shift; }
	else { return '' };
	}

sub test_line_substr {
	my $str = shift;
	my $sub_str = shift;
	if (index($str, $sub_str) < 0) { return shift; }
	else { return '' };
	}

1;
