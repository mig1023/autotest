package VCS::Settings::autotest;
use strict;

use VCS::Users::login;
use VCS::Users::register;
use VCS::Reports::docs;
use VCS::DHL;
use VCS::Vars;

use Data::Dumper;
use Storable;
use File::Find qw/find/;
use Date::Calc qw/Add_Delta_Days/;

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

	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'settings')) {
		$self->settings($task,$id,$template);

	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'settings_add')) {
		$self->settings_add($task,$id,$template);

	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'settings_del')) {
		$self->settings_del($task,$id,$template);
		
	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'settings_chng')) {
		$self->settings_chng($task,$id,$template);
		
	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'collect_chng')) {
		$self->collect_chng($task,$id,$template);
		
	} elsif (($vars->get_session->{'login'} ne '') && ($id eq 'collect_add')) {
		$self->collect_add($task,$id,$template);

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
	
	my $did;
	my $first_time_alert = '';
	
	my $settings_exist = $vars->db->sel1("SELECT CREATE_TIME FROM information_schema.tables ".
			"WHERE table_name = ? LIMIT 1", 'Autotest');
						
	if (!$settings_exist) {
	
		my $db_name = settings_default($vars);
		$first_time_alert = "alert('Модуль самотестирования запущен впервые, подключена новая БД или ".
				"данные настроек были утеряны. В БД " . $db_name . " создана таблица Autotest ".
				"с настройками по умолчанию.')";
		};
	
	# TT
	
	my $tt_adr_hash = $vars->db->selall("SELECT Value FROM Autotest WHERE Test = ? AND Param = ?", 
						'test9', 'page_adr');
	my $tt_adr = '';
	for my $hash_addr (@$tt_adr_hash) {
		my ($adr) = @$hash_addr;
		$tt_adr .= "'".$adr."', "; }	

	($did, my $settings_test9_ref) = get_settings($vars, 'test9', 'settings_test_ref');
	($did, my $settings_test9_404) = get_settings($vars, 'test9', 'settings_test_404');
	
	# TS
	
	my $centers_hash = $vars->db->selall("SELECT Value FROM Autotest WHERE Test = ? AND Param = ?", 
						'test1', 'centers');
	my $centers = '';
	my $centers_names = '';
	
	for my $hash_addr (@$centers_hash) {
		my ($cnt) = @$hash_addr;
		$centers .= $cnt.", ";
		$centers_names .= "'".get_center_name($vars, $cnt)."', "; }	
	
	($did, my $settings_test1_null) = get_settings($vars, 'test1', 'settings_test_null');
	($did, my $settings_test1_error) = get_settings($vars, 'test1', 'settings_test_error');
	
	# RP
	
	my $repen_hash = $vars->db->selall("SELECT Value FROM Autotest WHERE Test = ? AND ".
		"Param != 'settings_format_xml' and Param != 'settings_format_zip' and ".
		"Param != 'settings_format_pdf'", 'test4');
	
	my $report_enabled = '';
	
	for my $rep_en (@$repen_hash) {
		my ($rep_en2) = @$rep_en;
		$report_enabled .= ($rep_en2 ? "1" : "0").", "; }
	
	($did, my $settings_test4_xml) = get_settings($vars, 'test4', 'settings_format_xml');
	($did, my $settings_test4_pdf) = get_settings($vars, 'test4', 'settings_format_pdf');
	($did, my $settings_test4_zip) = get_settings($vars, 'test4', 'settings_format_zip');
	
	# AA
	
	my $test3_collection = '';
	my $settings_fixdate_num = 0;
	
	($did, my $settings_collect3_num) = get_settings($vars, 'test3', 'settings_collect_num');
	($did, my $settings_autodate) = get_settings($vars, 'test3', 'settings_autodate');
	($did, my $settings_fixdate) = get_settings($vars, 'test3', 'settings_fixdate');
	
	if ($settings_fixdate) {
		my @settings_fixdate = split /,/, $settings_fixdate;
		$settings_fixdate = join "','", @settings_fixdate;
		$settings_fixdate = "'".$settings_fixdate."'";
		$settings_fixdate =~ s/\s+//g;
		$settings_fixdate_num = scalar(@settings_fixdate);
		}
	
	for (1..$settings_collect3_num) {
		$test3_collection .= "'";
		
		my $coll_hash = $vars->db->selallkeys("SELECT Param, Value FROM Autotest ".
			"WHERE Test = ? AND Param LIKE ?", 'test3', $_.':%');
		
		for my $coll_pair (@$coll_hash) {
			$coll_pair->{Param} =~ s/^[^:]+?://;
			$test3_collection .= '&' . $coll_pair->{Param} . '=' . $coll_pair->{Value}; }	
		
		$test3_collection .= "', ";
		}
	
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
		'tt_adr'	=> $tt_adr,
		'first_time_alert' => $first_time_alert,
		'settings_test_ref' => $settings_test9_ref,
		'settings_test_404' => $settings_test9_404,
		'settings_test_null' => $settings_test1_null,
		'settings_test_error' => $settings_test1_error,
		'settings_test_xml' => $settings_test4_xml,
		'settings_test_pdf' => $settings_test4_pdf,
		'settings_test_zip' => $settings_test4_zip,
		'settings_collect3_num' => $settings_collect3_num,
		'settings_autodate' => $settings_autodate,
		'settings_fixdate' => $settings_fixdate,
		'settings_fixdate_num' => $settings_fixdate_num,
		'test3_collection' => $test3_collection,
		'report_enabled'=> $report_enabled,
		'centers'	=> $centers,
		'centers_names'	=> $centers_names,
		'session'	=> $vars->get_session,
		'menu'		=> $vars->admfunc->get_menu($vars)
	};
	$template->process('autotest.tt2',$tvars);
}

sub settings
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	my $settings = '';
	my $title_add = '';
	my $edit = $vars->getparam('edit') || '';
	
	if ($edit eq 'TT') {
		$title_add = 'Проверка страниц';
		my $tt_adr_hash = $vars->db->selall("SELECT ID, Value FROM Autotest WHERE Test = ? AND Param = ?", 'test9', 'page_adr');
		
		$settings .= '<b>настройки проверок</b><br><br>';
		my ($id, $value) = get_settings($vars, 'test9', 'settings_test_ref');
		$settings .= settings_form_bool($id, 'проверять ссылки (REF, ARRAY и т.п.) вместо данных', $value, 'TT');
		($id, $value) = get_settings($vars, 'test9', 'settings_test_404');
		$settings .= settings_form_bool($id, 'проверять недоступность страниц', $value, 'TT');
		
		$settings .= '<b>добавить новую страницу в список проверяемых</b><br><br>';
		$settings .= settings_form_str_add('добавить страницу', 'test9', 'page_adr', 'TT' );
		
		$settings .= '<b>список проверяемых</b><br><br>';
		for my $hash_addr (@$tt_adr_hash) {
			my ($id, $adr) = @$hash_addr;
			$settings .= '<input type="button" id="settings_'.$id.
				'" value="удалить" onclick="location.pathname='."'".'/autotest/settings_del.htm?did='.$id.
				'&ret=TT'."'".'">&nbsp;'.$adr.'<br><br>'; }	
		}
	
	if ($edit eq 'TS') {
		$title_add = 'Проверка временных интервалов';
		my $centers = $vars->db->selall("SELECT ID, Value FROM Autotest WHERE Test = ? AND Param = ?", 'test1', 'centers');
		
		$settings .= '<b>настройки проверок</b><br><br>';
		my ($id, $value) = get_settings($vars, 'test1', 'settings_test_error');
		$settings .= settings_form_bool($id, 'проверять ошибки/невозможность записаться', $value, 'TS');
		($id, $value) = get_settings($vars, 'test1', 'settings_test_null');
		$settings .= settings_form_bool($id, 'проверять пустые списки временных интервалов', $value, 'TS');
		
		$settings .= '<b>добавить новый центр в список проверяемых (по номеру)</b><br><br>';
		$settings .= settings_form_str_add('добавить центр', 'test1', 'centers', 'TS' );
		
		$settings .= '<b>список проверяемых центров</b><br><br>';
		for my $center (@$centers) {
			my ($id, $cnt) = @$center;
			my $bname = get_center_name($vars, $cnt);
			
			$settings .= '<input type="button" id="settings_'.$id.
				'" value="удалить" onclick="location.pathname='."'".'/autotest/settings_del.htm?did='.$id.
				'&ret=TS'."'".'">&nbsp;'.$cnt.'&nbsp;('.$bname.')<br><br>'; }	
		}
		
	if ($edit eq 'SQL') {
		$title_add = 'Проверка SQL-запросов';
		
		$settings .= '<b>настройки проверок</b><br><br>';
		my ($id, $value) = get_settings($vars, 'test7', 'settings_test_select');
		$settings .= settings_form_bool($id, 'проверять SELECT-запросы', $value, 'SQL');
		($id, $value) = get_settings($vars, 'test7', 'settings_test_insert');
		$settings .= settings_form_bool($id, 'проверять INSERT-запросы', $value, 'SQL');
		($id, $value) = get_settings($vars, 'test7', 'settings_test_update');
		$settings .= settings_form_bool($id, 'проверять UPDATE-запросы', $value, 'SQL');
		}
		
	if ($edit eq 'MT') {
		$title_add = 'Модульные тесты';
		my $modul_hash = $vars->db->selall("SELECT ID, Param FROM Autotest WHERE Test = ?", 'test5');
		
		$settings .= '<b>включение/отключение отдельных тестов</b><br><br>';

		for my $modul (@$modul_hash) {
			my ($nn_id, $modul_name) = @$modul;
			my ($id, $value) = get_settings($vars, 'test5', $modul_name);
			$settings .= settings_form_bool($id, $modul_name, $value, 'MT');
			}	
		}
		
	if ($edit eq 'UP') {
		$title_add = 'Проверка состояний';
		
		$settings .= '<b>настройки проверок</b><br><br>';

		my ($id, $value) = get_settings($vars, 'test11', 'settings_test_oldlist');
		$settings .= settings_form_bool($id, 'проверять отсутствие актуальных прайсов', $value, 'UP');
		($id, $value) = get_settings($vars, 'test11', 'settings_test_difeuro');
		$settings .= settings_form_bool($id, 'проверять отклонение евро от актуального прайса', $value, 'UP');
		
		$settings .= '<b>процент допустимого отклонение евро от актуального прайса</b><br><br>';
		($id, $value) = get_settings($vars, 'test11', 'settings_test_difper');
		$settings .= settings_form_str_chng('изменить', $id, $value,  'UP');
		
		$settings .= '<b>количество дней актуальности прайса</b><br><br>';
		($id, $value) = get_settings($vars, 'test11', 'settings_test_difday');
		$settings .= settings_form_str_chng('изменить', $id, $value,  'UP');
		}
		
	if ($edit eq 'SY') {
		$title_add = 'Проверка синтаксиса';
		
		$settings .= '<b>настройки проверок</b><br><br>';

		my ($id, $value) = get_settings($vars, 'test10', 'settings_perlc');
		$settings .= settings_form_bool($id, 'проверять с помощью perl -c', $value, 'SY');
		}
	
	if ($edit eq 'TR') {
		$title_add = 'Проверка перевода';
		
		$settings .= '<b>поиск русских букв без вызова подпрограмм перевода</b><br><br>';
		
		my ($id, $value) = get_settings($vars, 'test6', 'settings_rb_langreq');
		$settings .= settings_form_bool($id, 'без вызова langreq / getLangSesVar / getGLangVar / getLangVar', $value, 'TR');
		($id, $value) = get_settings($vars, 'test6', 'settings_rb_comm');
		$settings .= settings_form_bool($id, 'игнорировать закомментированное', $value, 'TR');
		
		$settings .= '<b>отсутствие в словаре перевода</b><br><br>';
		
		($id, $value) = get_settings($vars, 'test6', 'settings_dict_langreq');
		$settings .= settings_form_bool($id, 'для langreq', $value, 'TR');
		($id, $value) = get_settings($vars, 'test6', 'settings_dict_getLangVar');
		$settings .= settings_form_bool($id, 'для getLangVar', $value, 'TR');
		}
		
	if ($edit eq 'RP') {
		$title_add = 'Доступность отчётов';
		
		$settings .= '<b>допустимые форматы отчётов</b><br><br>';
		
		my ($id, $value) = get_settings($vars, 'test4', 'settings_format_xml');
		$settings .= settings_form_bool($id, 'XML', $value, 'RP');
		($id, $value) = get_settings($vars, 'test4', 'settings_format_pdf');
		$settings .= settings_form_bool($id, 'PDF', $value, 'RP');
		($id, $value) = get_settings($vars, 'test4', 'settings_format_zip');
		$settings .= settings_form_bool($id, 'ZIP', $value, 'RP');
		
		my $report_hash = $vars->db->selall("SELECT ID, Param FROM Autotest WHERE Test = ? AND ".
		"Param != 'settings_format_xml' and Param != 'settings_format_zip' and ".
		"Param != 'settings_format_pdf'", 'test4');
		
		$settings .= '<b>включение/отключение проверки конкретных отчётов</b><br><br>';

		for my $report (@$report_hash) {
			my ($nn_id, $report_name) = @$report;
			my ($id, $value) = get_settings($vars, 'test4', $report_name);
			$settings .= settings_form_bool($id, $report_name, $value, 'RP');
			}	
		}
	
	if ($edit eq 'AA') {
		$title_add = 'Доступность записи (add app)';
		
		my $collect = $vars->getparam('collect') || '';
		my $del = $vars->getparam('del') || '';
		my $add = $vars->getparam('add') || '';
		
		if (!$collect and !$del and !$add) {
		
			$settings .= '<b>настройки проверок</b><br><br>';
			my ($did, $value) = get_settings($vars, 'test3', 'settings_autodate');
			$settings .= settings_form_bool($did, 'автоматический выбор даты', $value, 'AA');
		
			$settings .= '<b>список дат для проверки (в формате "дд.мм.гггг, дд.мм.гггг, ...") при выключенном автовыборе</b><br><br>';
			($did, $value) = get_settings($vars, 'test3', 'settings_fixdate');
			$value = '' if !$value;
			$settings .= settings_form_str_chng('сохранить', $did, $value, 'AA' );
		
			$settings .= 	'<b>добавить новый набор данных для проверки</b><br><br>'.
					'<input type="button" id="collect_add" value="добавить"'.
					' onclick="location.href=\'/autotest/settings.htm?edit=AA&add=1\'"><br><br>'.
					'<b>наборы данных для проверки</b><br><br>';

			($did, my $settings_collect3_num) = get_settings($vars, 'test3', 'settings_collect_num');

			for (1..$settings_collect3_num) {
				($did, my $settings_collect_name) = get_settings($vars, 'test3', 
					'settings_collect_name_'.$_);
				$settings .= settings_form_collect('AA', $_, $settings_collect_name); }
			}
			
		elsif ($collect and !$del and !$add) {
			my ($did, $settings_collect_name) = get_settings($vars, 'test3', 
					'settings_collect_name_'.$collect);
					
			$settings .= 	'<form action="/autotest/collect_chng.htm">'.
					'<b>название набора:</b><br><br><input type="edit" '.
					'name="collect_new_name" value="'.$settings_collect_name.
					'" size="43"><br><br><input type="hidden" name="collect_name_id" '.
					'value="'.$did.'"><b>набор данных для проверки:</b><br><br>';
			
			$settings .= settings_full_collect($vars, 'AA', $collect);
			
			$settings .= 	'<input type="hidden" name="collect" value="'.$collect.'">'.
					'<input type="hidden" name="ret" value="AA">'.
					'<input type="submit" id="collect_submit" '.
					'value="сохранить изменения"></form><br>'.
					'<b>добавить новое поле в набор:</b><br><br>'.
					'<form action="/autotest/collect_add.htm">'.
					'<input type="edit" name="param"> = <input type="edit" name="value"><br><br>'.
					'<input type="hidden" name="test" value="test3">'.
					'<input type="hidden" name="collect" value="'.$collect.'">'.
					'<input type="hidden" name="ret" value="AA">'.
					'<input type="submit" id="submit" value="добавить"></form><br>';
			}
		elsif ($collect and $del) {
			my $r = $vars->db->query("DELETE FROM Autotest WHERE Test = ? AND Param LIKE ?", {},
				'test3', $collect.':%');
			$r = $vars->db->query("DELETE FROM Autotest WHERE Test = ? AND Param = ?", {},
				'test3', 'settings_collect_name_'.$collect);
			my ($did, $value) = get_settings($vars, 'test3', 'settings_collect_num');
			
			if ($value > $collect) {
				for my $col_renum(($collect+1)..$value) {
					my $new_index = $col_renum - 1;
					my $coll_hash = $vars->db->selallkeys("SELECT ID, Param FROM Autotest ".
						"WHERE Test = ? AND Param LIKE ?", 'test3', $col_renum.':%');
					for my $coll_pair (@$coll_hash) {
						$coll_pair->{Param} =~ s/^[^:]+?://;
						$r = $vars->db->query('UPDATE Autotest SET Param = ? WHERE '.
							'ID = ?', {}, $new_index.':'.$coll_pair->{Param}, 
							$coll_pair->{ID});
						}
					($did, my $name_col) = get_settings($vars, 'test3', 
						'settings_collect_name_'.$col_renum);
					$r = $vars->db->query('UPDATE Autotest SET Param = ? WHERE ID = ?', {},
						'settings_collect_name_'.$new_index, $did);						
				} }
			
			$value--;
			$r = $vars->db->query('UPDATE Autotest SET Value = ? WHERE test = ? and Param = ?', {},
				$value, 'test3', 'settings_collect_num');
			$vars->get_system->redirect($vars->getform('fullhost').'/autotest/settings.htm?edit=AA');
			}
		elsif ($add) {
			my ($did, $new_index) = get_settings($vars, 'test3', 'settings_collect_num');		
			$new_index++;
		
			my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
				'test3', 'settings_collect_name_'.$new_index, 'новый набор параметров '.$new_index);
			$r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
				'test3', $new_index.':whompass', '0808AUTOTEST');
			$r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
				'test3', $new_index.':passnum-1', '0909AUTOTEST');
			$r = $vars->db->query('UPDATE Autotest SET Value = ? WHERE test = ? and Param = ?', {},
				$new_index, 'test3', 'settings_collect_num');
				
			$vars->get_system->redirect($vars->getform('fullhost').
				'/autotest/settings.htm?edit=AA&collect='.$new_index);
			}
		}
		
	$vars->get_system->pheader($vars);
	my $tvars = {
		'langreq'  => sub { return $vars->getLangSesVar(@_) },
		'vars' =>	{
			'lang' => $vars->{'lang'},
			'page_title'  => 'Самотестирование / Настройки / ' . $title_add,
					},
		'form' =>	{
			'action' => $vars->getform('action')
					},
		'settings_place' => $settings,
		'edit_page'	=> $edit,
		'session'	=> $vars->get_session,
		'menu'		=> $vars->admfunc->get_menu($vars)
	};
	$template->process('autotest_settings.tt2',$tvars);
}

sub settings_del
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	my $del_id = $vars->getparam('did') || '';
	$del_id =~ s/[^\d]+//gi;
	my $ret = $vars->getparam('ret') || '';
	
	my $r = $vars->db->query('DELETE FROM Autotest WHERE ID = ?',{}, $del_id);
	$vars->get_system->redirect($vars->getform('fullhost').'/autotest/settings.htm?edit='.$ret);
}

sub settings_add
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	my $test = $vars->getparam('test') || '';
	my $param = $vars->getparam('param') || '';
	my $value = $vars->getparam('value') || '';
	my $ret = $vars->getparam('ret') || '';
	
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) '.
				'VALUES (?,?,?)', {}, $test, $param, $value);
	$vars->get_system->redirect($vars->getform('fullhost').'/autotest/settings.htm?edit='.$ret);
}

sub settings_chng
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	my $did = $vars->getparam('did') || '';
	my $value = $vars->getparam('value') || '';
	my $ret = $vars->getparam('ret') || '';
	
	my $r = $vars->db->query('UPDATE Autotest SET Value=? WHERE ID = ?', {}, $value, $did);
	$vars->get_system->redirect($vars->getform('fullhost').'/autotest/settings.htm?edit='.$ret);
}

sub collect_chng
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	my $collect_name = $vars->getparam('collect_new_name') || '';
	my $collect_name_id = $vars->getparam('collect_name_id') || '';
	my $num_param = $vars->getparam('num_param') || '';
	my $collect = $vars->getparam('collect') || '';
	my $ret = $vars->getparam('ret') || '';
	
	my $err = $vars->db->query("UPDATE Autotest SET Value = ? WHERE ID = ?", {}, 
			$collect_name, $collect_name_id);

	for (1..$num_param) {
		my $param_name = $vars->getparam('param-'.$_) || ''; 
		my $param_value = $vars->getparam('value-'.$_) || ''; 
		my $param_id = $vars->getparam('id-'.$_) || ''; 

		$err = $vars->db->query("UPDATE Autotest SET Param = ?, Value = ? WHERE ID = ?", {}, 
			$collect.':'.$param_name, $param_value, $param_id);
		}
		
	$vars->get_system->redirect($vars->getform('fullhost').'/autotest/settings.htm?edit='.$ret);
}

sub get_settings
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $test_name = shift;
	my $param_name = shift;
	
	my ($test_id, $test_value) = $vars->db->sel1('select ID, VALUE from Autotest '.
			'where test = ? and param = ?', $test_name, $param_name);

	$test_value = 0 if (!$test_value);

	return $test_id, $test_value;
}

sub settings_form_bool
# //////////////////////////////////////////////////
{

	my $did = shift;
	my $name = shift;
	my $current_value = shift;
	my $ret_addr = shift;
	
	my $res_str =   '<form action="/autotest/settings_chng.htm">'.
			'<input type="submit" id="settings_chng" value="'.($current_value ? 'отключить' : 'включить').'">'.
			'<input type="hidden" name="ret" value="'.$ret_addr.'">'.
			'<input type="hidden" name="did" value="'.$did.'">'.
			'<input type="hidden" name="value" value="'.(!$current_value).'">'.
			'&nbsp;'.$name.'&nbsp;<span class="ramka_'.( $current_value ? 
			'green">&nbsp;включено&nbsp;' : 'red">&nbsp;отключено&nbsp;' ).
			'</span></form><br>';

	return $res_str;
}

sub settings_form_str_add
# //////////////////////////////////////////////////
{
	my $res_str =   '<form action="/autotest/settings_add.htm">'.
			'<input type="submit" id="settings_add" value="'.shift.'">'.
			'<input type="hidden" name="test" value="'.shift.'">'.
			'<input type="hidden" name="param" value="'.shift.'">'.
			'<input type="hidden" name="ret" value="'.shift.'">'.
			'&nbsp;<input type="edit" name="value"></form><br>';

	return $res_str;
}

sub settings_form_str_chng
# //////////////////////////////////////////////////
{
	my $res_str =   '<form action="/autotest/settings_chng.htm">'.
			'<input type="submit" id="settings_add" value="'.shift.'">'.
			'<input type="hidden" name="did" value="'.shift.'">'.
			'&nbsp;<input type="edit" name="value" value="'.shift.'">'.
			'<input type="hidden" name="ret" value="'.shift.'">'.
			'</form><br>';

	return $res_str;
}

sub settings_form_collect
# //////////////////////////////////////////////////
{
	my $test_index = shift;
	my $collect_num = shift;
	my $collect_name = shift;
	my $res_str = 	'<input type="button" id="collect_del" value="удалить"'.
			' onclick="location.href=\'/autotest/settings.htm?edit='.$test_index.
			'&collect='.$collect_num.'&del=1\'">'.
			'&nbsp;&nbsp;<input type="button" id="collect_edit" value="изменить"'.
			' onclick="location.href=\'/autotest/settings.htm?edit='.$test_index.
			'&collect='.$collect_num.'\'">'.
			'&nbsp;'.$collect_name.'<br><br>'."\n";
	return $res_str;
}

sub settings_full_collect
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $test_index = shift;
	my $collect_num = shift;

	my $coll_hash = $vars->db->selallkeys("SELECT ID, Param, Value FROM Autotest ".
		"WHERE Test = ? AND Param LIKE ?", 'test3', $collect_num.':%');
	
	my $res_str = '';
	my $index_param = 0;
	
	for my $coll_pair (@$coll_hash) {
		$index_param++;
		$coll_pair->{Param} =~ s/^[^:]+?://;
		
		my $protect = 0;
		$protect = 1 if ($coll_pair->{Value} eq '0808AUTOTEST') or 
			($coll_pair->{Value} eq '0909AUTOTEST')	or ($coll_pair->{Value} eq '1010AUTOTEST');
		
		$res_str .=  '<input type="edit" name="param-'.$index_param.'" value="'.$coll_pair->{Param}.
			'" '.($protect ? 'readonly class="edit_dis"' : '').'> = <input type="edit" name="value-'.
			$index_param.'" value="'.$coll_pair->{Value}.'" '.
			($protect ? 'readonly class="edit_dis"' : '').'><br><br>';
		$res_str .= '<input type="hidden" name="id-'.$index_param.'" value="'.$coll_pair->{ID}.'">';
		}	
	
	$res_str .= '<input type="hidden" name="num_param" value="'.$index_param.'">';
		
	return $res_str;
}

sub collect_add
# //////////////////////////////////////////////////
{

	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	
	my $param = $vars->getparam('param') || '';
	my $value = $vars->getparam('value') || '';
	my $test = $vars->getparam('test') || '';
	my $collect = $vars->getparam('collect') || '';
	my $ret = $vars->getparam('ret') || '';
	
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			$test , $collect.':'.$param, $value);
	
	$vars->get_system->redirect($vars->getform('fullhost').'/autotest/settings.htm?edit='.
			$ret.'&collect='.$collect);
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

sub get_center_name
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $center = shift;
	my $bname = $vars->db->sel1('select BName from Branches where id = ?', $center);
	return $bname;	
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

my $rb_langreq = 1;
my $rb_comm = 1;
my $dict_langreq = 1;
my $dict_getLangVar = 1;

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
	
	$voc_cont = {};
	$voc = '';
	
	$vars->get_system->pheader($vars);
	$voc = retrieve($vocab);
	my $did;
	
	($did, $rb_langreq) = get_settings($vars, 'test6', 'settings_rb_langreq');
	($did, $rb_comm) = get_settings($vars, 'test6', 'settings_rb_comm');
	($did, $dict_langreq) = get_settings($vars, 'test6', 'settings_dict_langreq');
	($did, $dict_getLangVar) = get_settings($vars, 'test6', 'settings_dict_getLangVar');
	
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
			my $str = $_;
			
			if ($rb_langreq) { 
				if ( ($str =~ /[АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя]/) 
					and (!/(langreq|getLangSesVar|getGLangVar|getLangVar)/i) 
					and (!$rb_comm or !/#/) ) {  
						$ch++;
					} }
					
			if ($dict_langreq) {
				if ($str =~ /langreq\s?\(\s?\'([^\']+)\'\s?\)/i) {
					unless (exists($voc->{$1}->{'en'})) { 
						unless (exists($voc_cont->{$1})) { 
							$voc_cont->{$1} = '1';
							$ch2++;
					} } } }
				
			if ($dict_getLangVar) {
				if ($str =~ /getLangVar\s?\(\s?\'([^\']+)\'\s?\)/i) {
					unless (exists($voc->{$1}->{'en'})) {
						unless (exists($voc_cont->{$1})) {
							$voc_cont->{$1} = '1';
							$ch2++;
					} } } }

				
				}
		close $file_tmp;
		print '\\n'.$filename." (" if $ch or $ch2;
		print "нет langreq: $ch" if $ch; 
		print "/" if $ch and $ch2; 
		print "нет перевода: $ch2" if $ch2;
		print ") " if $ch or $ch2;
		}
	}

my $tables = {};
my $select_test = 1;
my $insert_test = 1;
my $update_test = 1;

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
	my $did;

	my $db_hash = get_db_hash($vars);
	
	($did, $select_test) = get_settings($vars, 'test7', 'settings_test_select');
	($did, $insert_test) = get_settings($vars, 'test7', 'settings_test_insert');
	($did, $update_test) = get_settings($vars, 'test7', 'settings_test_update');
	
	$tables = {};

	find( \&search_all_query, $path );
	
	for my $file (keys %$tables) {
		for my $tab (keys %{$tables->{$file}}) {
			for my $col (keys %{$tables->{$file}->{$tab}}) {
				next if ($tables->{$file}->{$tab}->{$col} eq '(select)') and !$select_test;
				next if ($tables->{$file}->{$tab}->{$col} eq '(insert)') and !$insert_test;
				next if ($tables->{$file}->{$tab}->{$col} eq '(update)') and !$update_test;
				
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
	
	@sql = () if !$select_test;
	@sql_insert = () if !$insert_test;
	@sql_update = () if !$update_test;
	
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
my $syntax_perlc = 1;

sub test_syntax
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;

	my $vars = $self->{'VCS::Vars'};
	
	my $path = '/usr/local/www/data/htdocs/vcs/lib/';
	
	(my $did, $syntax_perlc) = get_settings($vars, 'test10', 'settings_perlc');
	
	$synax_num = 0;
	$syntax_err = '';
	
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
	
	if (($filename =~ /\.pm$/i) or ($filename =~ /\.pl2$/i)) {
		if ($syntax_perlc) {
			$synax_num++;
			if (!(`perl -c -I '/usr/local/www/data/htdocs/vcs/lib/' $filename 2>&1` =~ /syntax OK/)) {		
				$syntax_err .= $filename." (ошибки синтаксиса)\\n";
				}
		} }
	}

sub test_update
# //////////////////////////////////////////////////
{
	my $self = shift;
	my $task = shift;
	my $id = shift;
	my $template = shift;
	my $did;

	my $vars = $self->{'VCS::Vars'};
	
	my $err = '';
	
	($did, my $test_oldlist) = get_settings($vars, 'test11', 'settings_test_oldlist');
	($did, my $test_difeuro) = get_settings($vars, 'test11', 'settings_test_difeuro');
	($did, my $def_percent) = get_settings($vars, 'test11', 'settings_test_difper');
	
	my $last_rate = $vars->db->selallkeys("select p.BranchID as R_id, max(p.RDate) as R_date, l.ConcilR ".
				"from Branches b join PriceRate p on b.ID = p.BranchID ".
				"join PriceList l on p.ID = l.RateID where VisaID = 1 group by p.BranchID");
	
	my ($day, $month, $year) = (localtime)[3..5];
	$month++; 
	$year += 1900;
	my $num_d = get_settings($vars, 'test11', 'settings_test_difday');
	
	for($day,$month) { $_ = "0$_" if ($_ < 10) && (!/^0/); };
	my $consil_current = fast_calc_consil("$day.$month.$year");
	$err .= 'недоступен API ЦБ РФ\\n' if !$consil_current;
	$consil_current = sprintf("%.2f",$consil_current); 
	
	my $date_current = "$year-$month-$day";
	
	if ($test_oldlist) {
		for my $l_rate(@$last_rate) {
			my ($pr_year, $pr_month, $pr_day) = split /-/,$l_rate->{R_date};
			($pr_year, $pr_month, $pr_day) = Add_Delta_Days($pr_year, $pr_month, $pr_day, $num_d);
			
			warn "$pr_year >= $year) and ($pr_month >= $month) and ($pr_day >= $day";
			$err .= 'cтарый прайслист ('.get_center_name($vars, $l_rate->{R_id}).' - '.$l_rate->{R_date}.')\\n'
				if ($pr_year <= $year) and ($pr_month <= $month) and ($pr_day < $day); }
		}
	
	if ($test_difeuro) {
		for my $l_rate(@$last_rate) {	
			$err .= get_center_name($vars, $l_rate->{R_id}).': изменение курса превышает допустмые '. 
					$def_percent.'% для актуального прайслиста\\n'
				if (($l_rate->{ConcilR}/100*$def_percent) < (abs($consil_current-$l_rate->{ConcilR}))); }
		}
	

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
		my ($did, $enabled) = get_settings($vars, 'test5', $test->{comment});
		next if !$enabled;
	
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
	
sub settings_default {
	my $vars = shift;

	my $tt_adr_default = [
		'admin/index.htm',		'admin/login.htm',		'admin/register.htm',
		'admin/success.htm',		'admin/verify.htm',		'admin/complete.htm',
		'admin/restrict.htm',		'personal/index.htm',		'admin/change_password_expired.htm',
		'personal/edit.htm',		'personal/password.htm',	'personal/success.htm',
		'users/index.htm',		'users/new.htm',		'users/locked.htm',
		'users/roles.htm',		'users/new_role.htm',		'users/role_info.htm',
		'users/find_user.htm',		'users/set_printer.htm',	'users/send_code.htm',
		'users/remind.htm',		'users/success_remind.htm',	'users/calc_consil.htm',
		'users/add_user.htm',		'settings/edit_timeslot.htm',	'settings/index.htm',
		'settings/centers.htm',		'settings/add_center.htm',	'settings/edit_center.htm',
		'settings/printers.htm',	'settings/holidays.htm',	'settings/timeslots.htm',
		'settings/edit_holiday.htm',	'settings/add_holiday.htm',	'settings/visatypes.htm',
		'settings/add_vtype.htm',	'settings/edit_vtype.htm',	'settings/blacklist.htm',
		'settings/add_blist.htm',	'settings/exclusions.htm',	'settings/add_excl.htm',
		'settings/edit_excl.htm',	'settings/pricelist.htm',	'settings/new_rate.htm',
		'settings/edit_rate.htm',	'settings/companies.htm',	'settings/edit_company.htm',
		'settings/new_company.htm',	'settings/compdov.htm',		'settings/edit_compdov.htm',
		'settings/new_compdov.htm',	'settings/load_dhl.htm',	'settings/edit_dhlcity.htm',
		'settings/dhl_prices.htm',	'settings/templates.htm',	'settings/edit_template.htm',
		'settings/new_template.htm',	'settings/view_template.htm',	'settings/managers.htm',
		'settings/cur_rates.htm',	'settings/localisation.htm',	'doc/index.htm',
		'doc/appointments.htm',		'doc/add_app.htm',		'doc/app_info.htm',
		'doc/note_info.htm',		'doc/recvideo.htm',		'doc/app_insurance.htm',
		'doc/edit_app.htm',		'doc/resch_app.htm',		'doc/add_applicant.htm',
		'doc/print_app.htm',		'doc/individuals.htm',		'doc/juridical.htm',
		'doc/print_labels.htm',		'doc/print_blabels.htm',	'doc/history.htm',
		'doc/edit_appl.htm',		'doc/status.htm',		'doc/print_banks.htm',
		'doc/get_info.htm',		'doc/set_fpstatus.htm',		'doc/app_anketa.htm',
		'doc/print_anketa.htm',		'doc/save_anketa.htm',		'doc/passrcv.htm',
		'doc/print_receipt.htm',	'appointments/get_dates.htm',	'appointments/get_times.htm',
		'appointments/get_vtypes.htm',	'appointments/new.htm',		'appointments/new_ins.htm',
		'appointments/group.htm',	'appointments/get_nearest.htm', 'appointments/add_applicant.htm',
		'report/index.htm',		'report/app_list.htm',		'report/app_summary.htm',
		'report/app_summaryvt.htm',	'report/doc_daily.htm',		'report/concil_summary.htm',
		'report/doc_summary.htm',	'report/personal_daily.htm',	'report/doc_status.htm',
		'report/doc_daily_full.htm',	'report/doc_registry.htm',	'report/concil_reg.htm',
		'report/fpvms.htm',		'report/fpvms3.htm',		'report/jur_1c.htm',
		'report/sms.htm',		'report/passlist.htm',		'report/sum_passlist.htm',
		'report/reconc_passlist.htm',	'report/jur_summary.htm',	'report/pers_detail.htm',
		'report/pers_average.htm',	'report/analize_eff.htm',	'report/jur_alldocs.htm',
		'report/jur_docs.htm',		'report/outdate.htm',		'report/delivery.htm',
		'report/docs_fio.htm',		'report/schengen_export.htm',	'report/site_feedback.htm',
		'report/doc_summary2.htm',	'report/macronumber.htm',	'report/summary_for_payment_type.htm',	
		'report/fpvms_period.htm',	'report/fpvms3_period.htm',	'report/doc_summary3.htm',
		'report/refusing.htm',		'report/fingers_list.htm',	'report/receivedpass.htm',
		'report/visafees.htm',		'report/acquiring.htm',		'individuals/index.htm',
		'individuals/new_contract.htm',	'individuals/transfer.htm',	'individuals/output.htm',
		'individuals/doc_info.htm',	'individuals/print_doc.htm',	'individuals/print_all.htm',
		'individuals/input.htm',	'individuals/set_transfer.htm',	'individuals/check_transfer.htm',
		'individuals/input_all.htm',	'individuals/payment.htm',	'individuals/edit_contract.htm',
		'individuals/delivery.htm',	'individuals/find_pcode.htm',	'individuals/print_dhl.htm',
		'individuals/schengen_reg.htm',	'individuals/for_mofa.htm',	'individuals/schengen_export.htm',
		'individuals/save_request.htm',	'individuals/received.htm',	'individuals/get_allowed_visa_types.htm',
		'individuals/new_received.htm',	'juridicals/index.htm',		'individuals/received_confirm.htm',
		'juridicals/new_contract.htm',	'juridicals/new_contract2.htm',	'juridicals/append_note.htm',
		'juridicals/notelst.htm',	'juridicals/transfer.htm',	'juridicals/output.htm',
		'juridicals/doc_info.htm',	'juridicals/print_doc.htm',	'juridicals/print_all.htm',
		'juridicals/set_transfer.htm',	'juridicals/transfer_all.htm',	'juridicals/input.htm',
		'juridicals/payment.htm',	'juridicals/edit_contract.htm',	'juridicals/delivery.htm',
		'juridicals/find_jname.htm',	'juridicals/find_bname.htm',	'juridicals/find_agr.htm',
		'juridicals/find_pass.htm',	'juridicals/schengen_reg.htm',	'vcs/index.htm',
		'vcs/new.htm',			'vcs/new0.htm',			'vcs/new1.htm',
		'vcs/new2.htm',			'vcs/new_v.htm',		'vcs/info_v.htm',
		'vcs/get_vtypes.htm',		'vcs/get_times.htm',		'vcs/info.htm',
		'vcs/success.htm',		'vcs/reschedule.htm',		'vcs/cancel.htm',
		'vcs/status.htm',		'vcs/get_nearest.htm',		'vcs/ivr.htm',
		'vcs/get_binfo.htm',		'vcs/show_a.htm',		'vcs/new_anketa.htm',
		'vcs/feedback.htm',		'vcs/short_form.htm',		'vcs/check_payment.htm',
		'vcs/long_form.htm',		'vcs/link_schengen.htm',	'vcs/print_receipt.htm',
		'vcs/send_app.htm',		'vcs/showlist.htm',		'vcs/load_foredit.htm',
		'vcs/num_current.htm',		'vcs/list_contract.htm',	'vcs/send_appointment.htm',
		'vcs/confirm_app.htm',		'vcs/del_app.htm',		'vcs/find_pcode.htm',
		'vcs/tmp_print.htm',		'vcs/appinfo.htm',		'vcs/show_print_est.htm',
		'vcs/post_price.htm',		'agency/index.htm',		'agency/login.htm',
		'agency/newnt.htm',		'agency/editnt.htm',		'agency/shownt.htm',
		'agency/regnt.htm',		'agency/confirm.htm',		'agency/updtnt.htm',
		'agency/saveapp.htm',		'agency/delapp.htm',		'agency/printnt.htm',
		'agency/printinv.htm',		'agency/get_times.htm',		'agency/xmlnt.htm',
		'agency/appinfo.htm',		'agency/anketa.htm',		'agency/search.htm',
		'agency/rmhotel.htm',		'agency/import_note.htm',	'agency/import_xml.htm',
		'agency/settings.htm',		'api/branches.htm',		'api/branches_auth.htm',
		'api/appointments.htm',		'nist/index.htm',		'nist/file.htm',
		'nist/receipt.htm',		'nist/upload.htm',		'nist/download.htm',
		]; # tt_adr_default
	
	my $ts_centers = [ 1, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 		
			46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61 ];
	
	my $modul_tests = [
		'AdminFunc / getPrices',	'AdminFunc / get_branch',	'AdminFunc / getAgrNumber',
		'AdminFunc / getRate',		'AdminFunc / sum_to_russtr',	'AdminFunc / get_pre_servicecode',
		'AdminFunc / get_currencies',	'List / getList',		'Config / getConfig',
		'Vars / getCaptchaErr',		'Vars / getConfig',		'Vars / getList',
		'Vars / getListValue',		'Vars / getparam',		'Vars / getGLangVar',
		'Vars / getLangVar',		'Vars / getLangSesVar',		'Vars / getform',
		'System / RTF_string',		'System / encodeurl',		'System / decodeurl',
		'System / cutEmpty',		'System / is_adult',		'System / is_child',
		'System / age',			'System / rus_letters_pass',	'System / transliteration',
		'System / to_lower_case',	'System / to_upper_case',	'System / to_upper_case_first',
		'System / get_fulldate',	'System / now_date',		'System / cmp_date',
		'System / time_to_str',		'System / str_to_time',		'System / appnum_to_str',
		'System / dognum_to_str',	'System / converttext',		'System / showHref',
		'System / showForm',		'System / check_mail_address',	'System / get_pages',
		]; # modul_tests
	
	my $report_name = [	'1-пвмс',
				'1-пвмс за указанный период',
				'3-пвмс',
				'3-пвмс за указанный период',
				'выгрузка данных в 1С',
				'cуточный отчёт по консульскому сбору',
				'cуточный отчёт по консульскому сбору (расширенный)',
				'итоговый отчет по услугам',
				'итоговый отчет по услугам (new)',
				'итоговый отчет по визам и услугам',
				'список договоров по статусам',
				'cводный реестр договоров за сутки',
				'cводный реестр оплаты консульского сбора',
				'cписок паспортов по статусу',
				'акт сверки паспортов',
				'сводный акт сверки паспортов',
				'итоговый отчет за период по юр. лицам',
				'отчет по договорам за период по юр. лицам',
				'отчет по дате вылета заявителей',
				'список договоров по типу оплаты',
				'отчет по отказам',
				'отчет по отпечаткам пальцев',
				'полученные паспорта',
				'отчёт по эквайрингу',
				'паспорта полученные из консульства',
				'отчет по деятельности сотрудников',
				'отчет об отправке SMS',
				'сообщения об ошибках с сайта',
		];
	
	my $test_addapp = {
		
		1 => { 	'sessionDuration' => '129048',		'cid' => '1',
			'vtype' => '19',			'concilfree-1' => '0',
			'pcnt' => '1',				'lname-1' => 'SURNAME',
			'fname-1' => 'NAME',			'passnum-1' => '0909AUTOTEST',
			'bdate-1' => '11.11.1980',		'citizenship-1' => '70',
			'rlname-1' => '',			'rfname-1' => '',
			'rmname-1' => '',			'rpassnum-1' => '',
			'rpassdate-1' => '',			'rpasswhom-1' => '',
			'amobile-1' => '',			'asaddr-1' => '',
			'whom' => '',				'whomlname' => 'ФАМИЛИЯ',
			'whomfname' => 'ИМЯ',			'whommname' => 'ОТЧЕСТВО',
			'whompass' => '0808AUTOTEST',		'whompassd' => '11.11.2010',
			'whompasso' => 'ОВД',			'shipnum' => '289',
			'phone' => '32141234',			'apptime' => '1366',
			},
		
		2 => { 	'sessionDuration' => '129048',		'cid' => '39',
			'vtype' => '16',			'concilfree-1' => '1',
			'pcnt' => '1',				'lname-1' => 'SURNAME',
			'fname-1' => 'NAME',			'passnum-1' => '0909AUTOTEST',
			'bdate-1' => '11.11.1980',		'citizenship-1' => '1',
			'rlname-1' => '',			'rfname-1' => '',
			'rmname-1' => '',			'rpassnum-1' => '',
			'rpassdate-1' => '',			'rpasswhom-1' => '',
			'amobile-1' => '',			'asaddr-1' => '',
			'whom' => '',				'whomlname' => 'ФАМИЛИЯ',
			'whomfname' => 'ИМЯ',			'whommname' => 'ОТЧЕСТВО',
			'whompass' => '0808AUTOTEST',		'whompassd' => '11.11.2010',
			'whompasso' => 'ОВД',			'shipnum' => '289',
			'phone' => '32141234',			'apptime' => '880',
			},

		3 => { 	'sessionDuration' => '129048',		'cid' => '29',
			'vtype' => '13',			'concilfree-1' => '0',
			'pcnt' => '1',				'lname-1' => 'SURNAME',
			'fname-1' => 'NAME',			'passnum-1' => '0909AUTOTEST',
			'bdate-1' => '11.11.1980',		'citizenship-1' => '19',
			'rlname-1' => '',			'rfname-1' => '',
			'rmname-1' => '',			'rpassnum-1' => '',
			'rpassdate-1' => '',			'rpasswhom-1' => '',
			'amobile-1' => '',			'asaddr-1' => '',
			'whom' => '',				'whomlname' => 'ФАМИЛИЯ',
			'whomfname' => 'ИМЯ',			'whommname' => 'ОТЧЕСТВО',
			'whompass' => '0808AUTOTEST',		'whompassd' => '11.11.2010',
			'whompasso' => 'ОВД',			'shipnum' => '289',
			'phone' => '32141234',			'apptime' => '1023',
			},
			
		4 => { 	'sessionDuration' => '129048',		'cid' => '61',
			'vtype' => '10',			'concilfree-1' => '1',
			'pcnt' => '1',				'lname-1' => 'SURNAME',
			'fname-1' => 'NAME',			'passnum-1' => '0909AUTOTEST',
			'bdate-1' => '11.11.1980',		'citizenship-1' => '30',
			'rlname-1' => '',			'rfname-1' => '',
			'rmname-1' => '',			'rpassnum-1' => '',
			'rpassdate-1' => '',			'rpasswhom-1' => '',
			'amobile-1' => '',			'asaddr-1' => '',
			'whom' => '',				'whomlname' => 'ФАМИЛИЯ',
			'whomfname' => 'ИМЯ',			'whommname' => 'ОТЧЕСТВО',
			'whompass' => '0808AUTOTEST',		'whompassd' => '11.11.2010',
			'whompasso' => 'ОВД',			'shipnum' => '289',
			'phone' => '32141234',			'apptime' => '1200',
			},
		
		5 => { 	'sessionDuration' => '129048',		'cid' => '53',
			'vtype' => '7',				'concilfree-1' => '0',
			'pcnt' => '1',				'lname-1' => 'SURNAME',
			'fname-1' => 'NAME',			'passnum-1' => '0909AUTOTEST',
			'bdate-1' => '11.11.1980',		'citizenship-1' => '98',
			'rlname-1' => '',			'rfname-1' => '',
			'rmname-1' => '',			'rpassnum-1' => '',
			'rpassdate-1' => '',			'rpasswhom-1' => '',
			'amobile-1' => '',			'asaddr-1' => '',
			'whom' => '',				'whomlname' => 'ФАМИЛИЯ',
			'whomfname' => 'ИМЯ',			'whommname' => 'ОТЧЕСТВО',
			'whompass' => '0808AUTOTEST',		'whompassd' => '11.11.2010',
			'whompasso' => 'ОВД',			'shipnum' => '289',
			'phone' => '32141234',			'apptime' => '1291',
			},
		
		};
	
	my $db_connect = VCS::Config->getConfig();

	my $r = $vars->db->query('CREATE TABLE Autotest (ID INT NOT NULL AUTO_INCREMENT, '.
			'Test VARCHAR(6), Param VARCHAR(256), Value VARCHAR(256), PRIMARY KEY (ID))', {});
	
	# TT	
	for (@$tt_adr_default) {
		my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) '.
			'VALUES (?,?,?)', {}, 'test9', 'page_adr', $_); };
	
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test9', 'settings_test_ref', 1);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test9', 'settings_test_404', 1);
	
	# TS
	
	for (@$ts_centers) {
		my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) '.
			'VALUES (?,?,?)', {}, 'test1', 'centers', $_); };
			
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test1', 'settings_test_null', 1);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test1', 'settings_test_error', 1);
	
	# SQL
	
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test7', 'settings_test_select', 1);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test7', 'settings_test_insert', 1);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test7', 'settings_test_update', 1);
	
	# MT
	for (@$modul_tests) {
		my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) '.
			'VALUES (?,?,?)', {}, 'test5', $_, 1); };
	
	# UP
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test11', 'settings_test_oldlist', 1);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test11', 'settings_test_difeuro', 1);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test11', 'settings_test_difper', 5);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test11', 'settings_test_difday', 0);
	
	# SY
	
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test10', 'settings_perlc', 1);
	
	# TR
	
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test6', 'settings_rb_langreq', 1);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test6', 'settings_rb_comm', 1);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test6', 'settings_dict_langreq', 1);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test6', 'settings_dict_getLangVar', 1);
	
	# RP
	
	for (@$report_name) {
		my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) '.
			'VALUES (?,?,?)', {}, 'test4', $_, 1); };
	
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test4', 'settings_format_pdf', 1);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test4', 'settings_format_zip', 1);
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test4', 'settings_format_xml', 1);
	
	# AA
	
	for my $test ( keys %$test_addapp ) {
		for my $param ( keys %{$test_addapp->{$test}} ) {
			my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) '.
				'VALUES (?,?,?)', {}, 'test3', $test.':'.$param, $test_addapp->{$test}->{$param} ); 
			}; 
		my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) '.
				'VALUES (?,?,?)', {}, 'test3', 'settings_collect_name_'.$test, 'встроенный набор параметров '.$test ); 
		};
	
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test3', 'settings_collect_num', scalar(keys %$test_addapp));
	my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test3', 'settings_autodate', 1);
		my $r = $vars->db->query('INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)', {},
			'test3', 'settings_fixdate', '');
	
	return $db_connect->{db}->{dbname};	
	}

1;
