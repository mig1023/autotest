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
  
    	my $dispathcher = {
    		'index' => \&autotest,
    		'captcha_h' => \&captcha_hack,
    		'test_and_clean' => \&test_and_clean,
    		'langreq' => \&langreq,
    		'sqltest' => \&sql_test,
    		'modultest' => \&modultest,
    		'get_aid' => \&get_aid,
    		'test_and_clean_doc' => \&test_and_clean_doc,
    		'test_syntax' => \&test_syntax,
    		'test_update' => \&test_update,
    		'settings' => \&settings,
    		'settings_add' => \&settings_add,
    		'settings_del' => \&settings_del,
    		'settings_chng' => \&settings_chng,
    		'collect_chng' => \&collect_chng,
    		'collect_add' => \&collect_add,
    	};
    	
    	my $disp_link = $dispathcher->{$id};
    	$vars->get_system->redirect($vars->getform('fullhost').'/admin/login.htm')
    		if !$disp_link or !$vars->get_session->{'login'};
    	&{$disp_link}($self, $task, $id, $template);
    	
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
	
	my $db_connect = VCS::Config->getConfig();
	my $db_name = $db_connect->{db}->{dbname};
	
	my $settings_exist = $vars->db->sel1("
			SELECT CREATE_TIME FROM information_schema.tables 
			WHERE table_schema = ? and table_name = ? LIMIT 1",
			$db_name, 'Autotest');
	
	if (!$settings_exist) {
		settings_default($vars);
		$first_time_alert = "alert('Модуль самотестирования запущен впервые, подключена новая БД или ".
			"данные настроек были утеряны.\\nВ текущей БД $db_name создана таблица Autotest ".
			"с настройками по умолчанию.');";
	};
		
	my $id_from_docpack = $vars->db->sel1("select ID from DocPack where PassNum = '101010AUTOTEST'");
	my $id_from_docpack_list = $vars->db->sel1("select ID from DocPackList where PassNum = '0909AUTOTEST'");
	my $id_from_app = $vars->db->sel1("select ID from Appointments where PassNum = '0808AUTOTEST'");
	my $id_from_appdata = $vars->db->sel1("select ID from AppData where PassNum = '0909AUTOTEST'");
	
	if ($id_from_app or $id_from_appdata or $id_from_docpack or $id_from_docpack_list) {
		$first_time_alert .= 
			"alert('В текущей БД обнаружены данные с уникальными номерами паспортов: \\n\\n".
			($id_from_docpack ? "101010AUTOTEST в таблице DocPack \\n" : '').
			($id_from_docpack_list ? "0909AUTOTEST в таблице DocPackList \\n" : '').
			($id_from_app  ? "0808AUTOTEST в таблице Appointments \\n" : '').
			($id_from_appdata ? "0909AUTOTEST в таблице AppData \\n" : '').
			"\\nТакие номера используются для тестирования данным модулем. Их наличие в БД может ".
			"быть результатом прекращения работы модуля во время тестирования. ".
			"Они будут удалены в процессе полной проверки, но это может исказить результаты ".
			"первой предстоящей проверки. На последующих проверках это не скажется.');";
	};
	
	# TT
	
	my $tt_adr_arr = get_settings_list( $vars, 'test9', 'page_adr' );
	my $tt_adr = join ',', map { $_ = "'$_->[0]'" } @$tt_adr_arr;
	
	my $settings = {};
	my $get_setting_general = {
		'test9_ref' => [ 'test9', 'settings_test_ref' ],
		'test9_404' => [ 'test9', 'settings_test_404' ],
		'test1_null' => [ 'test1', 'settings_test_null' ],
		'test1_error' => [ 'test1', 'settings_test_error' ],
		'day_slots_test' => [ 'test1', 'day_slots_test' ],
		'far_far_day' => [ 'test1', 'far_far_day' ],
		'test4_xml' => [ 'test4', 'settings_format_xml' ],
		'test4_pdf' => [ 'test4', 'settings_format_pdf' ],
		'test4_zip' => [ 'test4', 'settings_format_zip' ],
		'collect3_num' => [ 'test3', 'settings_collect_num' ],
		'autodate' => [ 'test3', 'settings_autodate' ],
		'fixdate' => [ 'test3', 'settings_fixdate' ],
		'collect2_num' => [ 'test2', 'settings_collect_num' ],
		'test2_autodate' => [ 'test2', 'settings_autodate' ],
		'test2_appdate' => [ 'test2', 'settings_appdate' ],
		'test2_fixdate_s' => [ 'test2', 'settings_fixdate_s' ],
		'test2_fixdate_e' => [ 'test2', 'settings_fixdate_e' ],
		'collect8_num' => [ 'test8', 'settings_collect_num' ],
		'test8_fixdate_s' => [ 'test8', 'settings_fixdate_s' ],
		'test8_fixdate_e' => [ 'test8', 'settings_fixdate_e' ],
		'test8_concildate' => [ 'test8', 'settings_concildate' ],
		'test8_autodate' => [ 'test8', 'settings_autodate' ],
	};
	
	for my $set (keys %$get_setting_general) {
		( $did, $settings->{$set} ) = get_settings( $vars, $get_setting_general->{ $set } );
	}

	# TS
	
	my $centers_arr =  get_settings_list( $vars, 'test1', 'centers' );
	my $centers = join ',', map { $_ = "'$_->[0]'" } @$centers_arr;
	
	my $centers_names_arr = get_settings_list( $vars, 'test1', 'centers' );
	my $centers_names = join ',', map { $_ = "'".get_center_name($vars, $_->[0])."'" } @$centers_names_arr;

	# RP
	
	my $repen_arr = $vars->db->selall("
		SELECT Value FROM Autotest WHERE Test = ? AND Param != 'settings_format_xml' 
		AND Param != 'settings_format_zip' AND Param != 'settings_format_pdf'", 'test4');
	
	my $report_enabled = join ',', map { $_ = ( $_->[0] ? 1 : 0 ) } @$repen_arr;
	
	# AA
	
	my $test3_collection = '';
	my $settings_fixdate_num = 0;
	
	if ( $settings->{fixdate} ) {
		( $settings->{fixdate}, $settings_fixdate_num ) = fix_dates_str( $settings->{fixdate} ); 
	};
	
	for ( 1..$settings->{collect3_num} ) {
		$test3_collection .= "'" . get_settings_collection( $vars, 'test3', $_ ) . "', ";
	}
	
	# SF
	
	my $test2A_collection = '';
	my $test2B_collection = '';
	my $settings_test2_fixdate_num = 0;
	my $settings_test2_appdate_num = 0;
	
	for ( 1..$settings->{collect2_num} ) {
		$test2A_collection .= "'" . get_settings_collection( $vars, 'test2A', $_ ) . "', ";
		$test2B_collection .= "'" . get_settings_collection( $vars, 'test2B', $_ ) . "', ";
	}

	if ( $settings->{test2_fixdate_s} ) {
		( $settings->{test2_fixdate_s}, $settings_test2_fixdate_num ) = fix_dates_str( $settings->{test2_fixdate_s} );
		( $settings->{test2_fixdate_e}, $settings_test2_fixdate_num ) = fix_dates_str( $settings->{test2_fixdate_e} );
		( $settings->{test2_appdate}, $settings_test2_appdate_num ) = fix_dates_str( $settings->{test2_appdate} ); 
	};

	# TC
	
	my $test8_collection = '';
	my $settings_test8_fixdate_num = 0;
	my $settings_test8_concildate_num = 0;

	if ( $settings->{test8_fixdate_s} ) {
		( $settings->{test8_fixdate_s}, $settings_test8_fixdate_num ) = fix_dates_str($settings->{test8_fixdate_s} );
		( $settings->{test8_fixdate_e}, $settings_test8_fixdate_num ) = fix_dates_str($settings->{test8_fixdate_e} ); 
		( $settings->{test8_concildate}, $settings_test8_concildate_num ) = fix_dates_str($settings->{test8_concildate} ); 
	}
	
	for ( 1..$settings->{collect8_num} ) {
		$test8_collection .= "'" . get_settings_collection( $vars, 'test8', $_ ) . "', ";
	}

	$vars->get_system->pheader($vars);
	my $tvars = {
		'langreq' => sub { return $vars->getLangSesVar(@_) },
		'vars' => {
				'lang' => $vars->{'lang'},
				'page_title'  => 'Самотестирование'
				},
		'form' => {
				'action' => $vars->getform('action')
				},
		'tt_adr' => $tt_adr,
		'first_time_alert' => $first_time_alert,
		'fixdate_num' => $settings_fixdate_num,
		'test3_collection' => $test3_collection,
		'test2a_collection' => $test2A_collection,
		'test2b_collection' => $test2B_collection,
		'test2_fixdate_num' => $settings_test2_fixdate_num,
		'test2_appdate_num' => $settings_test2_appdate_num,
		'test8_collection' => $test8_collection,
		'test8_fixdate_num' => $settings_test8_fixdate_num,
		'test8_concildate_num' => $settings_test8_concildate_num,
		'report_enabled'=> $report_enabled,
		'centers' => $centers,
		'centers_names'	=> $centers_names,
		'session' => $vars->get_session,
		'menu' => $vars->admfunc->get_menu($vars)
	};
	
	for (keys %$settings) {
		$tvars->{$_} = $settings->{$_};
	}
	
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
		
		my $tt_adr_arr = $vars->db->selall("
			SELECT ID, Value FROM Autotest WHERE Test = ? AND Param = ?", 
			'test9', 'page_adr');
		
		$settings .= title('настройки проверок');
		$settings .= settings_form_bool($vars, 'test9', 'settings_test_ref', 
			'проверять ссылки (REF, ARRAY и т.п.) вместо данных', 'TT');
		$settings .= settings_form_bool($vars, 'test9', 'settings_test_404', 
			'проверять недоступность страниц', 'TT');
		
		$settings .= title('добавить новую страницу в список проверяемых');
		$settings .= settings_form_str_add('добавить страницу', 'test9', 'page_adr', 'TT' );
		
		$settings .= title('список проверяемых');
		for my $addr (@$tt_adr_arr) {
			$settings .= 
				'<input type="button" id="settings_'.$addr->[0].'" value="удалить" '.
				'onclick="location.pathname='."'".'/autotest/settings_del.htm?did='.$addr->[0].
				'&ret=TT'."'".'">&nbsp;'.$addr->[1].'<br><br>';
		}	
	}
	
	if ($edit eq 'TS') {
		$title_add = 'Проверка временных интервалов';
		
		my $centers = $vars->db->selall("
			SELECT ID, Value FROM Autotest WHERE Test = ? AND Param = ?", 
			'test1', 'centers');
		
		$settings .= title('настройки проверок');
		
		my $all_settings = {
			'settings_test_error' => 'проверять ошибки/невозможность записаться',
			'settings_test_null' => 'проверять пустые списки временных интервалов',
			'far_far_day' => 'проверять отдалённый день',
		};

		for ( keys %$all_settings ) {
			$settings .= settings_form_bool($vars, 'test1', $_, $all_settings->{ $_ }, 'TS');
		}
		
		$settings .= title('количество календарных дней для проверки');
		$settings .= settings_form_str_chng($vars, 'test1', 'day_slots_test', 'изменить', 'TS');
		
		$settings .= title('добавить новый центр в список проверяемых (по номеру)');
		$settings .= settings_form_str_add('добавить центр', 'test1', 'centers', 'TS' );
		
		$settings .= title('список проверяемых центров');
		
		for my $center (@$centers) {
			my ($id, $cnt) = @$center;
			my $bname = get_center_name($vars, $cnt);
				
			$settings .= input_html( "button", "settings_$id", "удалить", 
					'onclick="location.pathname=' .
					"'"."/autotest/settings_del.htm".'?'."did=$id&ret=TS'".'"' ) .
					'&nbsp;'.$cnt.'&nbsp;('.$bname.')<br><br>'; 
		}	
	}
		
	if ($edit eq 'SQL') {
		$title_add = 'Проверка SQL-запросов';
		
		$settings .= title('настройки проверок');
		
		for ('select', 'insert', 'update') {
			$settings .= settings_form_bool($vars, 'test7', "settings_test_$_", 'проверять '.uc($_).'-запросы', 'SQL');
		}
	}
		
	if ($edit eq 'MT') {
		$title_add = 'Модульные тесты';
		
		my $modul_hash = $vars->db->selall("
			SELECT ID, Param FROM Autotest WHERE Test = ?", 'test5');
		
		$settings .= title('включение/отключение отдельных тестов');

		for my $modul (@$modul_hash) {
			$settings .= settings_form_bool($vars, 'test5', $modul->[1], $modul->[1], 'MT');
		}	
	}
		
	if ($edit eq 'UP') {
		$title_add = 'Проверка состояний';
		
		$settings .= title('настройки проверок');

		$settings .= settings_form_bool($vars, 'test11', 'settings_test_oldlist', 'проверять отсутствие актуальных прайсов', 'UP');
		$settings .= settings_form_bool($vars, 'test11', 'settings_test_difeuro', 'проверять отклонение евро от актуального прайса', 'UP');
		
		$settings .= title('процент допустимого отклонение евро от актуального прайса');
		$settings .= settings_form_str_chng($vars, 'test11', 'settings_test_difper', 'изменить', 'UP');
		
		$settings .= title('количество дней актуальности прайса');
		$settings .= settings_form_str_chng($vars, 'test11', 'settings_test_difday', 'изменить', 'UP');
	}
		
	if ($edit eq 'SY') {
		$title_add = 'Проверка синтаксиса';
		
		$settings .= title('настройки проверок');

		$settings .= settings_form_bool($vars, 'test10', 'settings_perlc', 'проверять с помощью perl -c', 'SY');
	}
	
	if ($edit eq 'TR') {
		$title_add = 'Проверка перевода';
		
		$settings .= title('поиск русских букв без вызова подпрограмм перевода');
		
		$settings .= settings_form_bool($vars, 'test6', 'settings_rb_langreq',
			'без вызова langreq / getLangSesVar / getGLangVar / getLangVar', 'TR');
		$settings .= settings_form_bool($vars, 'test6', 'settings_rb_comm', 'игнорировать закомментированное', 'TR');
		
		$settings .= title('отсутствие в словаре перевода');
		
		$settings .= settings_form_bool($vars, 'test6', 'settings_dict_langreq', 'для langreq', 'TR');
		$settings .= settings_form_bool($vars, 'test6', 'settings_dict_getLangVar', 'для getLangVar', 'TR');
	}
		
	if ($edit eq 'RP') {
		$title_add = 'Доступность отчётов';
		
		$settings .= title('допустимые форматы отчётов');
		
		$settings .= settings_form_bool($vars, 'test4', 'settings_format_xml', 'XML', 'RP');
		$settings .= settings_form_bool($vars, 'test4', 'settings_format_pdf', 'PDF', 'RP');
		$settings .= settings_form_bool($vars, 'test4', 'settings_format_zip', 'ZIP', 'RP');
		
		my $report_hash = $vars->db->selall("
			SELECT ID, Param FROM Autotest WHERE Test = ? AND Param != 'settings_format_xml' 
			AND Param != 'settings_format_zip' and Param != 'settings_format_pdf'", 
			'test4');
		
		$settings .= title('включение/отключение проверки конкретных отчётов');

		for my $report (@$report_hash) {
			$settings .= settings_form_bool($vars, 'test4', $report->[1], $report->[1], 'RP');
		}	
	}
	
	if ($edit eq 'AA') {
		$title_add = 'Доступность записи (add app)';
		
		my $collect = $vars->getparam('collect') || '';
		my $del = $vars->getparam('del') || '';
		my $add = $vars->getparam('add') || '';
		
		if (!$collect and !$del and !$add) {
		
			$settings .= title('настройки проверок');
			$settings .= settings_form_bool($vars, 'test3', 'settings_autodate', 'автоматический выбор даты', 'AA');
		
			$settings .= title('список дат подачи заявки (в формате "дд.мм.гггг, дд.мм.гггг, ...") '.
				'при выключенном автовыборе');
				
			$settings .= settings_form_str_chng($vars, 'test3', 'settings_fixdate', 'сохранить', 'AA' );
		
			$settings .= 	title('добавить новый набор данных для проверки').
					'<input type="button" id="collect_add" value="добавить"'.
					' onclick="location.href=\'/autotest/settings.htm?edit=AA&add=1\'"><br><br>'.
					title('наборы данных для проверки');

			my ($did, $settings_collect3_num) = get_settings($vars, 'test3', 'settings_collect_num');

			for (1..$settings_collect3_num) {
				($did, my $settings_collect_name) = get_settings($vars, 'test3', 
					'settings_collect_name_'.$_);
				$settings .= settings_form_collect('AA', $_, $settings_collect_name);
			}
		}
			
		elsif ($collect and !$del and !$add) {
			my ($did, $settings_collect_name) = get_settings($vars, 'test3', 
					'settings_collect_name_'.$collect);
					
			$settings .= 	'<form action="/autotest/collect_chng.htm">'.
					title('название набора:').'<input type="edit" '.
					'name="collect_new_name" value="'.$settings_collect_name.
					'" size="43"><br><br><input type="hidden" name="collect_name_id" '.
					'value="'.$did.'"><b>набор данных для проверки:</b><br>';
			
			$settings .= 	'APP_DATE - автоматически заменяется на дату подачи заявки<br><br>';
			
			$settings .= settings_full_collect($vars, 'test3', $collect);
			$settings .= settings_form_add_into_collect ($collect, 'test3', 'AA')
		}
			
		elsif ($collect and $del) {
			my $r = $vars->db->query("DELETE FROM Autotest WHERE Test = ? AND Param LIKE ?", {},
				'test3', $collect.':%');
				
			$r = $vars->db->query("DELETE FROM Autotest WHERE Test = ? AND Param = ?", {},
				'test3', 'settings_collect_name_'.$collect);
				
			my ($did, $value) = get_settings($vars, 'test3', 'settings_collect_num');
			
			if ($value > $collect) {
				for my $col_renum( ($collect+1)..$value ) {
					my $new_index = $col_renum - 1;
					
					my $coll_hash = $vars->db->selallkeys("
						SELECT ID, Param FROM Autotest WHERE Test = ? AND Param LIKE ?", 
						'test3', $col_renum.':%');
						
					for my $coll_pair (@$coll_hash) {
						$coll_pair->{Param} =~ s/^[^:]+?://;
						$r = $vars->db->query("
							UPDATE Autotest SET Param = ? WHERE ID = ?", 
							{}, $new_index.':'.$coll_pair->{Param}, $coll_pair->{ID});
						}
					($did, my $name_col) = get_settings($vars, 'test3', 
						'settings_collect_name_'.$col_renum);
						
					$r = $vars->db->query("
						UPDATE Autotest SET Param = ? WHERE ID = ?", {},
						'settings_collect_name_'.$new_index, $did);						
				}
			}
			
			$value--;
			$r = $vars->db->query('UPDATE Autotest SET Value = ? WHERE test = ? and Param = ?', {},
				$value, 'test3', 'settings_collect_num');
			$vars->get_system->redirect($vars->getform('fullhost').'/autotest/settings.htm?edit=AA');
		}
		elsif ($add) {
			my ($did, $new_index) = get_settings($vars, 'test3', 'settings_collect_num');		
			$new_index++;
		
			my $insert_arr = [
				[ 'test3', 'settings_collect_name_'.$new_index, 'новый набор параметров '.$new_index ],
				[ 'test3', $new_index.':whompass', '0808AUTOTEST' ],
				[ 'test3', $new_index.':passnum-1', '0909AUTOTEST' ],
			];
		
			for my $insert ( @$insert_arr ) {
				my $r = $vars->db->query("
					INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)", {},
					@$insert );
			}
			
			my $r = $vars->db->query("
				UPDATE Autotest SET Value = ? WHERE test = ? and Param = ?", {},
				$new_index, 'test3', 'settings_collect_num');
				
			$vars->get_system->redirect($vars->getform('fullhost').
				'/autotest/settings.htm?edit=AA&collect='.$new_index);
		}
	}
	
	if ($edit eq 'SF') {
		$title_add = 'Доступность записи (short form)';
		
		my $collect = $vars->getparam('collect') || '';
		my $del = $vars->getparam('del') || '';
		my $add = $vars->getparam('add') || '';
		
		if (!$collect and !$del and !$add) {
		
			$settings .= title('настройки проверок');
			$settings .= settings_form_bool($vars, 'test2', 'settings_autodate', 'автоматический выбор даты', 'SF');
		
			$settings .= title('список дат для проверки (в формате "дд.мм.гггг, дд.мм.гггг, ...") '.
				'при выключенном автовыборе');
			
			$settings .= 'даты заявки<br>';
			$settings .= settings_form_str_chng($vars, 'test2', 'settings_appdate',	'сохранить', 'SF' );
			
			$settings .= 'даты начала поездки<br>';
			$settings .= settings_form_str_chng($vars, 'test2', 'settings_fixdate_s', 'сохранить', 'SF' );
			
			$settings .= 'даты окончания поездки<br>';
			$settings .= settings_form_str_chng($vars, 'test2', 'settings_fixdate_e', 'сохранить', 'SF' );
		
			$settings .= 	title('добавить новый набор данных для проверки').
					'<input type="button" id="collect_add" value="добавить"'.
					' onclick="location.href=\'/autotest/settings.htm?edit=SF&add=1\'"><br><br>'.
					title('наборы данных для проверки');

			my ($did, $settings_collect2_num) = get_settings($vars, 'test2', 'settings_collect_num');

			for (1..$settings_collect2_num) {
				($did, my $settings_collect_name) = get_settings($vars, 'test2', 
					'settings_collect_name_'.$_);
				$settings .= settings_form_collect('SF', $_, $settings_collect_name); 
			}
		}
			
		elsif ($collect and !$del and !$add) {
			my ($did, $settings_collect_name) = get_settings($vars, 'test2', 
					'settings_collect_name_'.$collect);
					
			$settings .= 	'<form action="/autotest/collect_chng.htm">'.
					title('название набора:').'<input type="edit" '.
					'name="collect_new_name" value="'.$settings_collect_name.
					'" size="43"><br><br><input type="hidden" name="collect_name_id" '.
					'value="'.$did.'"><b>набор данных для проверки: ПЕРВЫЙ ШАГ:</b><br>';
			
			$settings .= 	'APP_DATE - автоматически заменяется на дату подачи заявки<br>'.
					'START_DATE - на дату начала поездки<br>'.
					'END_DATE - на дату окончания поездки<br><br>';
			
			$settings .= settings_full_collect($vars, 'test2A', $collect);
			$settings .= settings_form_add_into_collect ($collect, 'test2A', 'SF');
						
			$settings .= 	'<form action="/autotest/collect_chng.htm">'.
					'<input type="hidden" name="collect_new_name" value="'.$settings_collect_name.
					'" size="43"><br><br><input type="hidden" name="collect_name_id" '.
					'value="'.$did.'"><b>набор данных для проверки: ВТОРОЙ ШАГ:</b><br>';
			
			$settings .= 	'APP_DATE - автоматически заменяется на дату подачи заявки<br>'.
					'START_DATE - на дату начала поездки<br>'.
					'END_DATE - на дату окончания поездки<br><br>';
					
			$settings .= settings_full_collect($vars, 'test2B', $collect);
			$settings .= settings_form_add_into_collect ($collect, 'test2B', 'SF');
		}

		elsif ($collect and $del) {
			my $r = $vars->db->query("
				DELETE FROM Autotest WHERE Test = ? AND Param LIKE ?", {},
				'test2', $collect.':%');
				
			$r = $vars->db->query("
				DELETE FROM Autotest WHERE Test = ? AND Param = ?", {},
				'test2', 'settings_collect_name_'.$collect);
				
			my ($did, $value) = get_settings($vars, 'test2', 'settings_collect_num');
			
			if ($value > $collect) {
				for my $col_renum(($collect+1)..$value) {
				
					my $new_index = $col_renum - 1;
					
					my $coll_hash = $vars->db->selallkeys("
						SELECT ID, Param FROM Autotest WHERE Test = ? AND Param LIKE ?",
						'test2', $col_renum.':%');
						
					for my $coll_pair (@$coll_hash) {
						$coll_pair->{Param} =~ s/^[^:]+?://;
						
						$r = $vars->db->query("
							UPDATE Autotest SET Param = ? WHERE ID = ?", 
							{}, $new_index.':'.$coll_pair->{Param}, 
							$coll_pair->{ID});
					}
					($did, my $name_col) = get_settings($vars, 'test2', 
						'settings_collect_name_'.$col_renum);
						
					$r = $vars->db->query("
						UPDATE Autotest SET Param = ? WHERE ID = ?", {},
						'settings_collect_name_'.$new_index, $did);
				}
			}
			
			$value--;
			$r = $vars->db->query("
				UPDATE Autotest SET Value = ? WHERE test = ? and Param = ?", {},
				$value, 'test2', 'settings_collect_num');
				
			$vars->get_system->redirect($vars->getform('fullhost').'/autotest/settings.htm?edit=SF');
		}
		elsif ($add) {
			my ($did, $new_index) = get_settings($vars, 'test2', 'settings_collect_num');		
			$new_index++;
		
			my $insert_arr = [
				[ 'test2', 'settings_collect_name_'.$new_index, 'новый набор параметров '.$new_index ],
				[ 'test2A', $new_index.':dovpassnum', '0808AUTOTEST' ],
				[ 'test2A', $new_index.':app_1_passnum', '0909AUTOTEST' ],
				[ 'test2B', $new_index.':dovpassnum', '0808AUTOTEST' ],
				[ 'test2B', $new_index.':app_1_passnum', '0909AUTOTEST' ],
			];
		
			for my $insert ( @$insert_arr ) {
				my $r = $vars->db->query("
					INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)", {},
					@$insert );
			}
			
			my $r = $vars->db->query("
				UPDATE Autotest SET Value = ? WHERE test = ? and Param = ?", {},
				$new_index, 'test2', 'settings_collect_num');
				
			$vars->get_system->redirect($vars->getform('fullhost').
				'/autotest/settings.htm?edit=SF&collect='.$new_index);
		}
	}
		
	if ($edit eq 'TC') {
		$title_add = 'Доступность создания договора';
		
		my $collect = $vars->getparam('collect') || '';
		my $del = $vars->getparam('del') || '';
		my $add = $vars->getparam('add') || '';
		
		if (!$collect and !$del and !$add) {
		
			$settings .= title('настройки проверок');
			$settings .= settings_form_bool($vars, 'test8', 'settings_autodate', 'автоматический выбор даты', 'TC');
		
			$settings .= title('список дат подачи заявки (в формате "дд.мм.гггг, дд.мм.гггг, ...") '.
				'при выключенном автовыборе');
				
			$settings .= 'даты начала поездки<br>';
			$settings .= settings_form_str_chng($vars, 'test8', 'settings_fixdate_s', 'сохранить', 'TC' );
			
			$settings .= 'даты окончания поездки<br>';
			$settings .= settings_form_str_chng($vars, 'test8', 'settings_fixdate_e', 'сохранить', 'TC' );
		
			$settings .= title('даты оплаты консульского сбора (в формате "дд.мм.гггг, дд.мм.гггг, ...") '.
				'при выключенном автовыборе');
			$settings .= settings_form_str_chng($vars, 'test8', 'settings_concildate', 'сохранить', 'TC');
		
			$settings .= 	title('добавить новый набор данных для проверки').
					'<input type="button" id="collect_add" value="добавить"'.
					' onclick="location.href=\'/autotest/settings.htm?edit=TC&add=1\'"><br><br>'.
					title('наборы данных для проверки');

			my ($did, $settings_collect8_num) = get_settings($vars, 'test8', 'settings_collect_num');

			for (1..$settings_collect8_num) {
				($did, my $settings_collect_name) = get_settings($vars, 'test8', 
					'settings_collect_name_'.$_);
				$settings .= settings_form_collect('TC', $_, $settings_collect_name); 
			}
		}
			
		elsif ($collect and !$del and !$add) {
			my ($did, $settings_collect_name) = get_settings($vars, 'test8', 
					'settings_collect_name_'.$collect);
					
			$settings .= 	'<form action="/autotest/collect_chng.htm">'.
					title('название набора:').'<input type="edit" '.
					'name="collect_new_name" value="'.$settings_collect_name.
					'" size="43"><br><br><input type="hidden" name="collect_name_id" '.
					'value="'.$did.'"><b>набор данных для проверки:</b><br>';
			
			$settings .= 	'APPLID - автоматически заменяется на номер AppData<br>'.
					'START_DATE - на дату начала поездки<br>'.
					'END_DATE - на дату окончания поездки<br>'.
					'CONCIL_DATE - на дату оплаты консульского сбора<br><br>';
			
			$settings .= settings_full_collect($vars, 'test8', $collect);
			$settings .= settings_form_add_into_collect ($collect, 'test8', 'TC');
		}

		elsif ($collect and $del) {
			my $r = $vars->db->query("
				DELETE FROM Autotest WHERE Test = ? AND Param LIKE ?", {},
				'test8', $collect.':%');
				
			$r = $vars->db->query("
				DELETE FROM Autotest WHERE Test = ? AND Param = ?", {},
				'test8', 'settings_collect_name_'.$collect);
				
			my ($did, $value) = get_settings($vars, 'test8', 'settings_collect_num');
			
			if ($value > $collect) {
				for my $col_renum(($collect+1)..$value) {
				
					my $new_index = $col_renum - 1;
					
					my $coll_hash = $vars->db->selallkeys("
						SELECT ID, Param FROM Autotest WHERE Test = ? AND Param LIKE ?",
						'test8', $col_renum.':%');
						
					for my $coll_pair (@$coll_hash) {
						$coll_pair->{Param} =~ s/^[^:]+?://;
						
						$r = $vars->db->query("
							UPDATE Autotest SET Param = ? WHERE ID = ?",
							{}, $new_index.':'.$coll_pair->{Param},	$coll_pair->{ID});
					}
					($did, my $name_col) = get_settings($vars, 'test8', 
						'settings_collect_name_'.$col_renum);
						
					$r = $vars->db->query("
						UPDATE Autotest SET Param = ? WHERE ID = ?", {},
						'settings_collect_name_'.$new_index, $did);
				}
			}
			
			$value--;
			$r = $vars->db->query("
				UPDATE Autotest SET Value = ? WHERE test = ? and Param = ?", {},
				$value, 'test8', 'settings_collect_num');
			$vars->get_system->redirect($vars->getform('fullhost').'/autotest/settings.htm?edit=TC');
		}
		elsif ($add) {
			my ($did, $new_index) = get_settings($vars, 'test8', 'settings_collect_num');		
			$new_index++;
		
			my $insert_arr = [
				[ 'test8', 'settings_collect_name_'.$new_index, 'новый набор параметров '.$new_index ],
				[ 'test8', $new_index.':mpass', '101010AUTOTEST' ],
			];
		
			for my $insert ( @$insert_arr ) {
				my $r = $vars->db->query("
					INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)", {},
					@$insert );
			}

			my $r = $vars->db->query("
				UPDATE Autotest SET Value = ? WHERE test = ? and Param = ?", {},
				$new_index, 'test8', 'settings_collect_num');
				
			$vars->get_system->redirect($vars->getform('fullhost').
				'/autotest/settings.htm?edit=TC&collect='.$new_index);
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
	
	my $r = $vars->db->query("
		DELETE FROM Autotest WHERE ID = ?",
		{}, $del_id);
		
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
	
	my $r = $vars->db->query("
		INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)", 
		{}, $test, $param, $value);
		
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
	
	my $r = $vars->db->query("
		UPDATE Autotest SET Value=? WHERE ID = ?",
		{}, $value, $did);
		
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
	
	my $err = $vars->db->query("
		UPDATE Autotest SET Value = ? WHERE ID = ?",
		{}, $collect_name, $collect_name_id);

	for (1..$num_param) {
		my $param_name = $vars->getparam('param-'.$_) || ''; 
		my $param_value = $vars->getparam('value-'.$_) || ''; 
		my $param_id = $vars->getparam('id-'.$_) || ''; 

		$err = $vars->db->query("
			UPDATE Autotest SET Param = ?, Value = ? WHERE ID = ?",
			{}, $collect.':'.$param_name, $param_value, $param_id);
	}
		
	$vars->get_system->redirect($vars->getform('fullhost').'/autotest/settings.htm?edit='.$ret);
}

sub get_settings
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $test_name = shift;
	my $param_name = shift;
	
	my ($test_id, $test_value) = $vars->db->sel1("
		select ID, VALUE from Autotest where test = ? and param = ?", 
		$test_name, $param_name);

	$test_value = 0 if (!$test_value);

	return $test_id, $test_value;
}

sub get_settings_list
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $test_name = shift;
	my $param_name = shift;
	
	my $arr = $vars->db->selall("
		SELECT Value FROM Autotest WHERE Test = ? AND Param = ?", 
		$test_name, $param_name);

	return $arr;
}

sub get_settings_collection
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $test_name = shift;
	my $param_name = shift;
	
	my $test_collection = '';

	my $coll_hash = $vars->db->selallkeys("
		SELECT Param, Value FROM Autotest WHERE Test = ? AND Param LIKE ?", 
		$test_name, $param_name.':%');
	
	for my $coll_pair (@$coll_hash) {
		$coll_pair->{Param} =~ s/^[^:]+?://;
		$test_collection .= '&' . $coll_pair->{Param} . '=' . $coll_pair->{Value}; 
	}
		
	return $test_collection;
}



sub settings_form_bool
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $test_name = shift;
	my $test_value = shift;
	my $name = shift;
	my $ret_addr = shift;
	
	my ($did, $current_value) = get_settings( $vars, $test_name, $test_value );
	
	my $res_str =  	
		form_html( "/autotest/settings_chng.htm" ).
		input_html( "submit", "settings_chng", ( $current_value ? 'отключить' : 'включить' ) ) .
		input_html( "hidden", "ret", $ret_addr ) .
		input_html( "hidden", "did", $did ) .
		input_html( "hidden", "value", (!$current_value) ) .
		'&nbsp;' . $name . '&nbsp;<span class="ramka_' . 
		( $current_value ? 'green">&nbsp;включено&nbsp;' : 'red">&nbsp;отключено&nbsp;' ) .
		'</span></form><br>';

	return $res_str;
}

sub settings_form_str_add
# //////////////////////////////////////////////////
{
	my $res_str =   
		form_html( "/autotest/settings_add.htm" ).
		input_html( "submit", "settings_add", shift ) .
		input_html( "hidden", "test", shift ) .
		input_html( "hidden", "param", shift ) .
		input_html( "hidden", "ret", shift ) .
		'&nbsp;' . 
		input_html( "edit", "value" ) . 
		'</form><br>';

	return $res_str;
}

sub settings_form_str_chng
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $test_name = shift;
	my $test_value = shift;
	
	my ($did, $current_value) = get_settings($vars, $test_name, $test_value);
	$current_value = '' if !$current_value;

	my $res_str = 
		form_html( "/autotest/settings_chng.htm" ) .
		input_html( "submit", "settings_add", shift ) .
		input_html( "hidden", "did", $did ) .
		'&nbsp;' .
			
		input_html( "edit", "value", $current_value ) .
		input_html( "hidden", "ret", shift ).
		'</form><br>';
	
	return $res_str;
}

sub settings_form_collect
# //////////////////////////////////////////////////
{
	my $test_index = shift;
	my $collect_num = shift;
	my $collect_name = shift;
	
	my $res_str = 
		input_html( "button", "collect_del", "удалить",
		' onclick="location.href=\'/autotest/settings.htm?edit='.$test_index.
		'&collect='.$collect_num.'&del=1\'"' ) .
		'&nbsp;&nbsp;' .
			
		input_html( "button", "collect_edit", "изменить",
		' onclick="location.href=\'/autotest/settings.htm?edit='.$test_index.
		'&collect='.$collect_num.'\'"' ) .
		'&nbsp;'.$collect_name.'<br><br>'."\n";
		
	return $res_str;
}

sub settings_form_add_into_collect
# //////////////////////////////////////////////////
{
	my $collect = shift;
	my $test_num = shift;
	my $ret = shift;

	my $res_str = 
		input_html( "hidden", "collect", $collect ) .
		input_html( "hidden", "ret", $ret ) .
		input_html( "submit", "collect_submit", "сохранить изменения" ) . '</form><br>'.
		title( 'добавить новое поле в набор:' ) .
		form_html( "/autotest/collect_add.htm" ) .
		input_html( "edit", "param" ) . ' = ' . input_html( "edit", "value" ) . '<br><br>'.
		input_html( "hidden", "test", $test_num ) , '>' .
		input_html( "hidden", "collect", $collect) .
		input_html( "hidden", "ret", $ret ) .
		input_html( "submit", "submit", "добавить" ) . '</form><br>';
	
	return $res_str;
}

sub settings_full_collect
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $test_index = shift;
	my $collect_num = shift;

	my $coll_hash = $vars->db->selallkeys("
		SELECT ID, Param, Value FROM Autotest WHERE Test = ? AND Param LIKE ?", 
		$test_index, $collect_num.':%');
	
	my $res_str = '';
	my $index_param = 0;
	
	for my $coll_pair ( sort {$a->{Param} cmp $b->{Param}} @$coll_hash ) {
		$index_param++;
		$coll_pair->{Param} =~ s/^[^:]+?://;
		
		my $protect = 0;
		$protect = 1 if ($coll_pair->{Value} eq '0808AUTOTEST')
			or ($coll_pair->{Value} eq '0909AUTOTEST') 
			or ($coll_pair->{Value} eq '101010AUTOTEST');
		
		$res_str .=  
			input_html( "edit", "param-".$index_param, $coll_pair->{Param}, ($protect ? 'readonly class="edit_dis"' : '') ) .' = '. 
			input_html( "edit", "value-". $index_param, $coll_pair->{Value}, ($protect ? 'readonly class="edit_dis"' : '') ) .'<br><br>';
		
		$res_str .= input_html( "hidden", "id-".$index_param, $coll_pair->{ID} );
		}	
	
	$res_str .= input_html( "hidden", "num_param", $index_param );
		
	return $res_str;
}

sub title
# //////////////////////////////////////////////////
{
	return '<b>' . shift . '</b><br><br>';
}

sub form_html
# //////////////////////////////////////////////////
{
	return '<form action="' . shift . '">'
}

sub input_html
# //////////////////////////////////////////////////
{
	return '<input type="' . shift . '" id="' . shift . '" value="' . shift . '" '. shift .'>';
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
	
	my $r = $vars->db->query("
		INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)", {},
		$test , $collect.':'.$param, $value);
	
	$vars->get_system->redirect(
		$vars->getform('fullhost').'/autotest/settings.htm?edit='.$ret.'&collect='.$collect );
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
	
	unless ( $err ) { 
		print "ok";
	} else {
		print "captcha error";
	}
}

sub get_center_name
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $center = shift;
	my $bname = $vars->db->sel1("
		SELECT BName FROM Branches WHERE id = ?", $center);
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
	
	my ($id_app) = $vars->db->sel1("
		select ID from Appointments where PassNum = '0808AUTOTEST'");
	my ($id_app_data) = $vars->db->sel1("
		select ID from AppData where PassNum = '0909AUTOTEST'");
	
	$err = !( ($id_app != 0) and ($id_app_data != 0) );
	
	$vars->db->query("
		delete from Appointments where PassNum = '0808AUTOTEST'", {});
	$vars->db->query("
		delete from AppData where PassNum = '0909AUTOTEST'", {});
	
	$vars->get_system->pheader($vars);
	
	unless ( $err ) { 
		print "ok";
	} else {
		print "db error";
	}
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

sub search_all_folder
# //////////////////////////////////////////////////
{
	chomp $_;
	return if $_ eq '.' or $_ eq '..';
	read_files($_) if (-f);
}

sub read_files
# //////////////////////////////////////////////////
{
	my $filename = shift;
	
	if ( (($filename =~ /\.pm$/i) or ($filename =~ /\.tt2$/i))
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
				} 
			}
					
			if ($dict_langreq) {
				if ($str =~ /langreq\s?\(\s?\'([^\']+)\'\s?\)/i) {
					unless (exists($voc->{$1}->{'en'})) { 
						unless (exists($voc_cont->{$1})) { 
							$voc_cont->{$1} = '1';
							$ch2++;
						} 
					} 
				} 
			}
				
			if ($dict_getLangVar) {
				if ($str =~ /getLangVar\s?\(\s?\'([^\']+)\'\s?\)/i) {
					unless (exists($voc->{$1}->{'en'})) {
						unless (exists($voc_cont->{$1})) {
							$voc_cont->{$1} = '1';
							$ch2++;
						} 
					} 
				} 
			}
				
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
			}
		}
	}
		
	$vars->get_system->pheader($vars);
	if ($sql_r) { print $sql_r; } else { print "ok|$sql_num"; };
}

sub get_db_hash
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $hash = {};
	
	my $rws = $vars->db->selall("show tables");
	for my $row (@$rws) {
		my $rws2 = $vars->db->selall("
			select column_name from information_schema.columns where table_name = $row->[0]");
   		for my $row2 (@$rws2) {	
   			$row->[0] = lc($row->[0]);
   			$row2->[0] = lc($row2->[0]);
   			$hash->{$row->[0]}->{$row2->[0]} = 1;
		}
	}
	return $hash;
}
	
sub search_all_query
# //////////////////////////////////////////////////
{
	chomp $_;
	return if $_ eq '.' or $_ eq '..';
	query_search_files($_) if (-f);
}

sub query_search_files
# //////////////////////////////////////////////////
{
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
	
	my ($id_app) = $vars->db->sel1("
		select ID from Appointments where PassNum = '0808AUTOTEST'");
	my ($id_app_data) = $vars->db->sel1("
		select ID from AppData where PassNum = '0909AUTOTEST'");
	
	$vars->get_system->pheader($vars);
	
	if ( ($id_app != 0) && ($id_app_data != 0) ) {

		$err = $vars->db->query("
			update Appointments set AppDate = curdate() where ID = ?", 
			{}, $id_app);
			
		print $id_app.'|'.$id_app_data;
	}
	else {
		print "db error";
	}
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
	
	my ($id_app) = $vars->db->sel1("
		select ID from Appointments where PassNum = '0808AUTOTEST'");
	my ($id_app_data) = $vars->db->sel1("
		select ID from AppData where PassNum = '0909AUTOTEST'");
	my ($doc_pack) = $vars->db->sel1("
		select ID from DocPack where PassNum = '101010AUTOTEST'");
	my ($doc_pack_info) = $vars->db->sel1("
		select ID from DocPackInfo where PackID = ?", $doc_pack);
	
	$err = !(($id_app != 0) and ($id_app_data != 0) and (($doc_pack) != 0) and (($doc_pack_info) != 0));
	
	$vars->db->query("
		delete from DocPack where PassNum = '101010AUTOTEST'", {});
	$vars->db->query("
		delete from DocPackInfo where PackID = ?", {}, $doc_pack);
	$vars->db->query("
		delete from DocPackList where PassNum = '0909AUTOTEST'");
	
	$vars->get_system->pheader($vars);
	
	unless ( $err ) { 
		print "ok";
	} else {
		print "db error";
	}
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
	
	unless ( $syntax_err ) { 
		print "ok|$synax_num";
	} else {
		print $syntax_err;
	}
}

sub syntax_all_folder
# //////////////////////////////////////////////////
{
	chomp $_;
	return if $_ eq '.' or $_ eq '..';
	syntax_files($_) if (-f);
}

sub syntax_files
# //////////////////////////////////////////////////
{
	my $filename = shift;
	
	if (($filename =~ /\.pm$/i) or ($filename =~ /\.pl2$/i)) {
		if ($syntax_perlc) {
			$synax_num++;
			if (!(`perl -c -I '/usr/local/www/data/htdocs/vcs/lib/' $filename 2>&1` =~ /syntax OK/)) {		
				$syntax_err .= $filename." (ошибки синтаксиса)\\n";
			}
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
	my $did;

	my $vars = $self->{'VCS::Vars'};
	
	my $err = '';
	
	($did, my $test_oldlist) = get_settings($vars, 'test11', 'settings_test_oldlist');
	($did, my $test_difeuro) = get_settings($vars, 'test11', 'settings_test_difeuro');
	($did, my $def_percent) = get_settings($vars, 'test11', 'settings_test_difper');
	
	my $last_rate = $vars->db->selallkeys("
		select p.BranchID as R_id, max(p.RDate) as R_date, l.ConcilR from Branches b 
		join PriceRate p on b.ID = p.BranchID 
		join PriceList l on p.ID = l.RateID 
		where VisaID = 1 group by p.BranchID");
	
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
			
			$err .= 'cтарый прайслист ('.get_center_name($vars, $l_rate->{R_id}).' - '.$l_rate->{R_date}.')\\n'
				if ($pr_year < $year) or ($pr_month < $month) or ($pr_day < $day); }
		}
	
	if ($test_difeuro) {
		for my $l_rate(@$last_rate) {	
			$err .= get_center_name($vars, $l_rate->{R_id}).': изменение курса превышает допустмые '. 
					$def_percent.'%\\n'
				if (($l_rate->{ConcilR}/100*$def_percent) < (abs($consil_current-$l_rate->{ConcilR}))); }
		}
	

	$vars->get_system->pheader($vars);
	
	unless ( $err ) { 
		print "ok";
	} else {
		print $err;
	}
}

sub fast_calc_consil
# //////////////////////////////////////////////////
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
	my $vars_for_admfnc = new VCS::AdminFunc(qw( VCS::AdminFunc ));

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
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => ['',$vars,1595,1,'01.01.2010'], 
					'expected' => ['urgent','visa','photosrv'] },
				2 => { 	
					'args' => ['',$vars,1586,1,'01.01.2012'], 
					'expected' => ['vipsrv','shipnovat','xerox'] },
				3 => { 
					'args' => ['',$vars,1178,1,'01.01.2014'], 
					'expected' => ['shipping','printsrv','anketasrv'] }, 
				},
				
	},{ 	'func' => \&VCS::AdminFunc::get_branch,
		'comment' => 'AdminFunc / get_branch',
		'tester' => \&test_hash,
		'debug' => 0,
		'test' => { 	1 => { 	
					'args' => ['',$vars,1], 
					'expected' => ['calcInsurance','CollectDate','isPrepayedAppointment'] }, 
				2 => { 	
					'args' => ['',$vars,29], 
					'expected' => ['Embassy','persPerDHLPackage','isShippingFree'] },
				3 => { 	
					'args' => ['',$vars,39], 
					'expected' => ['cdSimpl','CTemplate','Timezone'] },
				},
				
	},{ 	'func' => \&VCS::AdminFunc::getAgrNumber,
		'comment' => 'AdminFunc / getAgrNumber',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => ['',$vars,1,'01.01.2010'], 
					'expected' => '0100000101.01.2010' },
				2 => { 
					'args' => ['',$vars,29,'01.01.2012'], 
					'expected' => '2900000101.01.2012' },
				3 => { 
					'args' => ['',$vars,39,'01.01.2014'], 
					'expected' => '3900000101.01.2014' }, 
				},
				
	},{ 	'func' => \&VCS::AdminFunc::getRate,
		'comment' => 'AdminFunc / getRate',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => ['',$vars,'RUR','31.12.2014',1], 
					'expected' => '1595' },
				2 => { 
					'args' => ['',$vars,'RUR','21.10.2014',29], 
					'expected' => '1604' },
				3 => { 
					'args' => ['',$vars,'RUR','20.10.2015',39], 
					'expected' => '1600' }, 
				},
				
	},{ 	'func' => \&VCS::AdminFunc::sum_to_russtr,
		'comment' => 'AdminFunc / sum_to_russtr',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => ['','RUR','10000.00'], 
					'expected' => 'ДЕСЯТЬ ТЫСЯЧ 00 КОПЕЕК' },
				2 => { 
					'args' => ['','EUR','33023.01'], 
					'expected' => 'ТРИДЦАТЬ ТРИ ТЫСЯЧИ ДВАДЦАТЬ ТРИ ЕВРО 01 ЕВРОЦЕНТ' },
				3 => { 
					'args' => ['','RUR','75862.21'], 
					'expected' => 'СЕМЬДЕСЯТ ПЯТЬ ТЫСЯЧ ВОСЕМЬСОТ ШЕСТЬДЕСЯТ ДВА РУБЛЯ 21 КОПЕЙКА' }, 
				},
				
	},{ 	'func' => \&VCS::AdminFunc::get_pre_servicecode,
		'comment' => 'AdminFunc / get_pre_servicecode',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => ['',$vars,'visa',{'center'=>1,'urgent'=>1,'jurid'=>1,'ptype'=>1} ], 
					'expected' => 'ITA00122' },
				2 => { 
					'args' => ['',$vars,'visa',{'center'=>14, 'urgent'=>0,'jurid'=>0,'ptype'=>2} ], 
					'expected' => 'ITA12201' },
				3 => { 
					'args' => ['',$vars,'concilc',{'center'=>20,'urgent'=>1,'jurid'=>0,'ptype'=>1} ], 
					'expected' => 'ITA19601' }, 
				},
				
	},{ 	'func' => \&VCS::AdminFunc::get_currencies,
		'comment' => 'AdminFunc / get_currencies',
		'tester' => \&test_hash,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => ['',$vars], 
					'expected' => [ 'RUR' ] },
				}, 
	
	},{ 	'func' => \&VCS::List::getList,
		'comment' => 'List / getList',
		'tester' => \&test_hash,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ 'null' ], 
					'expected' => [ 'gender', 'days', 'doc_status' ] }, 
				},
	
	},{ 	'func' => \&VCS::Config::getConfig,
		'comment' => 'Config / getConfig',
		'tester' => \&test_hash,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ 'null' ], 
					'expected' => [ 'general', 'dhl', 'sms_http', 'authlist', 'db', 'templates' ] }, 
				},
	
	},{ 	'func' => \&VCS::Vars::getCaptchaErr,
		'comment' => 'Vars / getCaptchaErr',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => ['', '0' ], 
					'expected' => 'Файл не найден' },
				2 => { 
					'args' => ['', '-1' ], 
					'expected' => 'Время действия кода истекло' },
				3 => { 
					'args' => ['', '-3' ], 
					'expected' => 'Неверно указан код на изображении' }, 
				},
				
	},{ 	'func' => \&VCS::Vars::getConfig,
		'comment' => 'Vars / getConfig',
		'tester' => \&test_hash,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ $vars_for_vars, 'dhl' ], 
					'expected' => [ 'PersonName', 'CompanyAddress', 'CompanyName' ] },
				2 => { 
					'args' => [ $vars_for_vars, 'templates' ], 
					'expected' => [ 'report', 'settings', 'nist' ] },
				3 => { 
					'args' => [ $vars_for_vars, 'general' ], 
					'expected' => [ 'base_currency', 'files_delivery', 'pers_data_agreem' ] }, 
				},
				
	},{ 	'func' => \&VCS::Vars::getList,
		'comment' => 'Vars / getList',
		'tester' => \&test_hash,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ $vars_for_vars, 'languages' ], 
					'expected' => [ 'ru', 'en', 'it' ] },
				2 => { 
					'args' => [ $vars_for_vars, 'app_status' ], 
					'expected' => [ 1, 3, 5 ] },
				3 => { 
					'args' => [ $vars_for_vars, 'service_codes' ], 
					'expected' => [ '01VP01', '11VP01', '15VP02' ] },
				},
				
	},{ 	'func' => \&VCS::Vars::getListValue,
		'comment' => 'Vars / getListValue',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ $vars_for_vars, 'days', 4 ], 
					'expected' => 'Thursday' },
				2 => { 
					'args' => [ $vars_for_vars, 'short_currency', 'RUR' ], 
					'expected' => 'руб.' },
				3 => { 
					'args' => [ $vars_for_vars, 'service_codes', '01VP03' ], 
					'expected' => 'ITA00201' }, 
				},
				
	},{ 	'func' => \&VCS::Vars::getparam,
		'comment' => 'Vars / getparam',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ $vars, 'test_param' ], 
					'expected' => 'test_is_ok' },
				2 => { 
					'args' => [ $vars, 'id' ], 
					'expected' => 'modultest' },
				3 => { 
					'args' => [ $vars, 'task' ], 
					'expected' => 'autotest' }, 
				},
				
	},{ 	'func' => \&VCS::Vars::getGLangVar,
		'comment' => 'Vars / getGLangVar',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 	
					'args' => [ $vars, 'doc_ready', 'ru' ], 
					'expected' => 'Документы готовы для получения' }, 
				2 => { 
					'args' => [ $vars, 'payed', 'en' ], 
					'expected' => 'The agreement has been paid' },
				3 => { 
					'args' => [ $vars, 'wait_for_payment', 'it' ], 
					'expected' => 'Pagamento del contratto da effettuare' }, 
				},
				
	},{ 	'func' => \&VCS::Vars::getLangVar,
		'comment' => 'Vars / getLangVar',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ $vars, 'doc_ready' ], 
					'expected' => 'Документы готовы для получения' },
				2 => { 
					'args' => [ $vars, 'payed' ], 
					'expected' => 'Договор оплачен' },
				3 => { 
					'args' => [ $vars, 'wait_for_payment' ], 
					'expected' => 'Ожидается оплата договора' }, 
				},
				
	},{ 	'func' => \&VCS::Vars::getLangSesVar,
		'comment' => 'Vars / getLangSesVar',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ $vars, 'doc_ready', 'ru' ], 
					'expected' => 'Документы готовы для получения' }, 
				2 => { 
					'args' => [ $vars, 'payed', 'en' ], 
					'expected' => 'Договор оплачен' },
				3 => { 
					'args' => [ $vars, 'wait_for_payment', 'it' ], 
					'expected' => 'Ожидается оплата договора' } 
				},
				
	},{ 	'func' => \&VCS::Vars::getform,
		'comment' => 'Vars / getform',
		'tester' => \&test_line_substr,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ $vars, 'fullhost' ], 
					'expected' =>  'http://' }, 
				2 => { 
					'args' => [ $vars, 'action' ], 
					'expected' => '/autotest/modultest.htm' } 
				},
				
	},{ 	'func' => \&VCS::System::RTF_string,
		'comment' => 'System / RTF_string',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ '', 'ABC', ], 
					'expected' => '\\u65?\\u66?\\u67?' }, 
				2 => { 
					'args' => [ '', '*/"""__', ], 
					'expected' => '\\u42?\\u47?\\u34?\\u34?\\u34?\\u95?\\u95?' } 
				},
				
	},{ 	'func' => \&VCS::System::encodeurl,
		'comment' => 'System / encodeurl',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ '', 'http://www.italy-vms.ru', ], 
					'expected' => 'http%3A%2F%2Fwww.italy-vms.ru' }, 
				2 => { 
					'args' => [ '', 'http://www.estonia-vms.ru', ],
					'expected' =>  'http%3A%2F%2Fwww.estonia-vms.ru' } 
				},
				
	},{ 	'func' => \&VCS::System::decodeurl,
		'comment' => 'System / decodeurl',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ '', 'http%3A%2F%2Fwww.italy-vms.ru', ], 
					'expected' =>  'http://www.italy-vms.ru' }, 
				2 => { 
					'args' => [ '', 'http%3A%2F%2Fwww.estonia-vms.ru', ], 
					'expected' => 'http://www.estonia-vms.ru' } 
				},
				
	},{ 	'func' => \&VCS::System::cutEmpty,
		'comment' => 'System / cutEmpty',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ '', '   ABCD       ', ], 
					'expected' => 'ABCD' }, 
				2 => { 
					'args' => [ '', '&nbsp;&nbsp;EFGH&nbsp;&nbsp;', ], 
					'expected' => 'EFGH' } 
				},
				
	},{ 	'func' => \&VCS::System::is_adult,
		'comment' => 'System / is_adult',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ '', '25.01.1998', '25.01.2016' ], 
					'expected' => 1 }, 
				2 => { 
					'args' => [ '', '26.01.1998', '25.01.2016' ], 
					'expected' => 0 },
				3 => { 
					'args' => [ '', '25.01.2015', '25.01.2016' ], 
					'expected' => 0 }, 
				},
				
	},{ 	'func' => \&VCS::System::is_child,
		'comment' => 'System / is_child',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ '', '24.01.2010', '25.01.2016' ], 
					'expected' => 0 }, 
				2 => { 
					'args' => [ '', '26.01.2010', '25.01.2016' ], 
					'expected' => 1 },
				3 => { 
					'args' => [ '', '25.01.2016', '25.01.2016' ], 
					'expected' => 1 }, 
				},
				
	},{ 	'func' => \&VCS::System::age,
		'comment' => 'System / age',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ '', '1998-01-25', '2016-01-25' ], 
					'expected' => 18 }, 
				2 => { 
					'args' => [ '', '1998-01-26', '2016-01-25' ], 
					'expected' => 17 },
				3 => { 
					'args' => [ '', '2010-01-26', '2016-01-25' ], 
					'expected' => 5 },
				4 => { 
					'args' => [ '', '2010-01-25', '2016-01-25' ], 
					'expected' => 6 },
				},
				
	},{ 	'func' => \&VCS::System::rus_letters_pass,
		'comment' => 'System / rus_letters_pass',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ '', $ru_utf_1 ],
					'expected' => 'ABCD' }, 
				2 => {
					'args' => [ '', $ru_utf_2 ],
					'expected' => 'EFE' }
				},
				
	},{ 	'func' => \&VCS::System::transliteration,
		'comment' => 'System / transliteration',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ '', $ru_utf_3 ], 
					'expected' => 'AABBVGCDD' }, 
				2 => { 
					'args' => [ '', $ru_utf_4 ],
					'expected' => 'EYAYOFYUYUIYE' }
				},
				
	},{ 	'func' => \&VCS::System::to_lower_case,
		'comment' => 'System / to_lower_case',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 
					'args' => [ '', 'ABCDEFGH' ],
					'expected' => 'abcdefgh' }, 
				2 => {
					'args' => [ '', 'D_E_F_H' ],
					'expected' => 'd_e_f_h' }
				},
				
	},{ 	'func' => \&VCS::System::to_upper_case,
		'comment' => 'System / to_upper_case',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', 'abcdefgh' ],
					'expected' => 'ABCDEFGH' }, 
				2 => {
					'args' => [ '', 'd_e_f_h' ],
					'expected' => 'D_E_F_H' }
				},
				
	},{ 	'func' => \&VCS::System::to_upper_case_first,
		'comment' => 'System / to_upper_case_first',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', 'abcdefgh' ],
					'expected' => 'Abcdefgh' }, 
				2 => {
					'args' => [ '', 'e_f_h' ],
					'expected' => 'E_f_h' }
				},
				
	},{ 	'func' => \&VCS::System::get_fulldate,
		'comment' => 'System / get_fulldate',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', 1453710363 ],
					'expected' => '25.01.2016 11:26:03' }, 
				2 => {
					'args' => [ '', 1403310427 ],
					'expected' => '21.06.2014 04:27:07' }
				},
				
	},{ 	'func' => \&VCS::System::now_date,
		'comment' => 'System / now_date',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', 1453710363 ],
					'expected' => '2016-01-25' }, 
				2 => {
					'args' => [ '', 1403310427 ],
					'expected' => '2014-06-21' }
				},
				
	},{ 	'func' => \&VCS::System::cmp_date,
		'comment' => 'System / cmp_date',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', '26.01.2016', '2016-01-25' ],
					'expected' => -1 }, 
				2 => {
					'args' => [ '', '2016-01-25', '25.01.2016' ],
					'expected' => 0 },
				3 => {
					'args' => [ '', '24.01.2016', '2016-01-25' ],
					'expected' => 1 }
				},
				
	},{ 	'func' => \&VCS::System::time_to_str,
		'comment' => 'System / time_to_str',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', 56589 ],
					'expected' => '15:43' }, 
				2 => {
					'args' => [ '', 75236 ],
					'expected' => '20:53' }
				},
				
	},{ 	'func' => \&VCS::System::str_to_time,
		'comment' => 'System / str_to_time',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', '15:43' ],
					'expected' => 56580 }, 
				2 => {
					'args' => [ '', '20:53' ],
					'expected' => 75180 }
				},
				
	},{ 	'func' => \&VCS::System::appnum_to_str,
		'comment' => 'System / appnum_to_str',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', '039201601250001' ],
					'expected' => '039/2016/01/25/0001' }, 
				2 => {
					'args' => [ '', '059201502530002' ],
					'expected' => '059/2015/02/53/0002' }
				},
				
	},{ 	'func' => \&VCS::System::dognum_to_str,
		'comment' => 'System / dognum_to_str',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', '29000001123015' ],
					'expected' => '29.000001.123015' }, 
				2 => {
					'args' => [ '', '01000002123015' ],
					'expected' => '01.000002.123015' }
				},
				
	},{ 	'func' => \&VCS::System::converttext,
		'comment' => 'System / converttext',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', 'A"B^C<D>E&F' ],
					'expected' => 'A&quot;B^C&lt;D&gt;E&F' }, 
				2 => {
					'args' => [ '', 'A"B^C<D>E&F', 1 ],
					'expected' => 'A&quot;B^C&lt;D&gt;E&amp;F' }
				},
				
	},{ 	'func' => \&VCS::System::showHref,
		'comment' => 'System / showHref',
		'tester' => \&test_line_substr,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', $vars, {1 => 'aa', 2 => 'bb'} ],
					'expected' => '/?1=aa&2=bb' }, 
				2 => {
					'args' => [ '', $vars, {1 => 'aa', 2 => 'bb'}, 1 ],
					'expected' => 'http://' }
				},
				
	},{ 	'func' => \&VCS::System::showForm,
		'comment' => 'System / showForm',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 	
					'args' => [ '', $vars, {1 => 'aa', 2 => 'bb'}, 0, 'name', 1 ], 
					'expected' => 	'<form action="/" method="POST" name="name" target="1">'.
							'<input type="hidden" name="1" value="aa"><input type="hidden" '.
							'name="2" value="bb">' }, 
				2 => { 	
					'args' => [ '', $vars, {1 => 'aa', 2 => 'bb'}, 1 ], 
					'expected' => 	'<form action="/" method="POST" enctype="multipart/form-data">'.
							'<input type="hidden" name="1" value="aa"><input type="hidden" '.
							'name="2" value="bb">' }, },
	},{ 	'func' => \&VCS::System::check_mail_address,
		'comment' => 'System / check_mail_address',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => {
					'args' => [ '', 'email_email.com' ], 
					'expected' => 0 }, 
				2 => {
					'args' => [ '', 'email@email' ],
					'expected' => 0 },
				3 => {
					'args' => [ '', 'email@email.com' ],
					'expected' => 1 },
				4 => {
					'args' => [ '', 'email@em*ail.com' ],
					'expected' => 0 }
				},
				
	},{ 	'func' => \&VCS::System::get_pages,
		'comment' => 'System / get_pages',
		'tester' => \&test_hash,
		'debug' => 0,
		'test' => { 	1 => { 	
					'args' => [ '', $vars, 'cms', 'location', 'SELECT Count(*) FROM Users', ['param'] ], 
					'expected' => [ 'position', 'show', 'pages' ] }, 
				},
				
	},{ 	'func' => \&VCS::AdminFunc::calculateCouncilFee,
		'comment' => 'AdminFunc / calculateCouncilFee',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 	
					'args' => [ $vars_for_admfnc, $vars, 0, '01.01.1980', '24.10.2015', 0, 0, 313, 13], 
					'expected' => '3500.00' }, 
				2 => { 	
					'args' => [ $vars_for_admfnc, $vars, 0, '01.01.1980', '24.10.2015', 1, 0, 313, 13], 
					'expected' => '7000.00' }, 
				3 => {
					'args' => [ $vars_for_admfnc, $vars, 0, '01.01.1980', '24.10.2015', 0, 1, 313, 13], 
					'expected' => '0' }, 
				4 => { 
					'args' => [ $vars_for_admfnc, $vars, 0, '01.01.2013', '24.10.2015', 0, 1, 313, 13], 
					'expected' => '0' },
				},
				
	},{ 	'func' => \&VCS::AdminFunc::getPricesByAge,
		'comment' => 'AdminFunc / getPricesByAge',
		'tester' => \&test_hash,
		'debug' => 0,
		'test' => { 	1 => { 	
					'args' => [ $vars_for_admfnc, $vars, 313, 1, '24.10.2015', 30 ], 
					'expected' => [ 'oconcilnu_6-12', 'age_suffix', 'visa_6-12' ] }, 
				2 => { 	
					'args' => [ $vars_for_admfnc, $vars, 313, 13, '24.10.2015', 5 ], 
					'expected' => [ 'jurgent_6-12', 'age_suffix', 'oconcilru_6-12' ] },
				},
	},{ 	'func' => \&VCS::AdminFunc::CalculateConcilFeeByAgreementApplicant,
		'comment' => 'AdminFunc / CalculateConcilFeeByAgreementApplicant',
		'tester' => \&test_line,
		'debug' => 0,
		'test' => { 	1 => { 	
					'args' => [ $vars_for_admfnc, $vars, '1815982' ], 
					'expected' => '2787.38' },
				2 => { 	
					'args' => [ $vars_for_admfnc, $vars, '1815821' ], 
					'expected' => '2651.15' },  
				3 => { 	
					'args' => [ $vars_for_admfnc, $vars, '1815978' ], 
					'expected' => '2716.11' }, 
				},
	},
	];
	
	for my $test (@$tests) {
		my ($did, $enabled) = get_settings($vars, 'test5', $test->{comment});
		next if !$enabled;
	
		my $err_tmp;
		for(keys %{$test->{test}}) {
			my $tmp_r = &{$test->{func}}(@{$test->{test}->{$_}->{args}});
			$err_tmp = &{$test->{tester}}($tmp_r, $test->{test}->{$_}->{expected},$test->{comment}) if !$err_tmp;
			warn Dumper($tmp_r, $test->{test}->{$_}->{expected}) if $test->{debug};
			$test_num++;
			} 
		$err .= "$err_tmp\\n" if $err_tmp;
		}
	$err =~ s/(^(\s|\n)+|(\s|\n)+$)//g;
	
	$vars->get_system->pheader($vars);	

	unless ( $err ) { 
		print "ok|$test_num";
	} else {
		print $err;
	}
}

sub test_hash
# //////////////////////////////////////////////////
{
	my $test_hash = shift;
	my $pattern_ar = shift;
	my $comment = shift;
	
	my $err = 0;
	
	for ( @$pattern_ar ) {
		$err = 1 if !exists($test_hash->{$_}); }
	
	if ( $err ) {
		return $comment; 
	} else {	
		return '';
	}
}

sub test_line
# //////////////////////////////////////////////////
{
	if ( shift ne shift ) { 
		return shift; 
	} else { 
		return '';
	};
}

sub test_line_substr
# //////////////////////////////////////////////////
{
	my $str = shift;
	my $sub_str = shift;
	
	if ( index($str, $sub_str) < 0 ) { 
		return shift;
	} else { 
		return '';
	};
}

sub fix_dates_str
# //////////////////////////////////////////////////
{
	my @fixdate = split /,/, shift;
	my $fixdate = join "','", @fixdate;
	$fixdate = "'".$fixdate."'";
	$fixdate =~ s/\s+//g;
	my $fixdate_num = scalar(@fixdate);

	return $fixdate, $fixdate_num;
}
	
sub default_config
# //////////////////////////////////////////////////
{
	my $vars = shift;
	my $test_num = shift;
	my $conf = shift;

	if  ( ref($conf) eq "HASH" ) {
		for ( keys (%$conf) ) {
			my $r = $vars->db->query("
				INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
				{}, $test_num, $_, $conf->{$_});
		}
	} else {
		for ( @$conf ) {
			my $r = $vars->db->query("
				INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
				{}, $test_num, $_, 1);
		};
	}
}
	
sub settings_default
# //////////////////////////////////////////////////
{
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
		'doc/print_anketa.htm',		'doc/save_anketa.htm',		
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
		'vcs/get_vtypes.htm',		'vcs/get_times.htm',		'vcs/info.htm',
		'vcs/success.htm',		'vcs/reschedule.htm',		'vcs/cancel.htm',
		'vcs/status.htm',		'vcs/get_nearest.htm',
		'vcs/new_anketa.htm',
		'vcs/feedback.htm',		'vcs/short_form.htm',		'vcs/check_payment.htm',
		'vcs/long_form.htm',		'vcs/link_schengen.htm',	'vcs/print_receipt.htm',
		'vcs/send_app.htm',		'vcs/showlist.htm',		'vcs/load_foredit.htm',
		'vcs/num_current.htm',		'vcs/list_contract.htm',	'vcs/send_appointment.htm',
		'vcs/confirm_app.htm',		'vcs/del_app.htm',		'vcs/find_pcode.htm',
		'vcs/appinfo.htm',		'vcs/show_print_est.htm',
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
		'AdminFunc / get_currencies',	'AdminFunc / getPricesByAge',	'AdminFunc / calculateCouncilFee',
		'AdminFunc / CalculateConcilFeeByAgreementApplicant',
		'List / getList',		'Config / getConfig',
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
		]; #report_name
	
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
			'appdate' => 'APP_DATE',
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
			'appdate' => 'APP_DATE',
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
			'appdate' => 'APP_DATE',
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
			'appdate' => 'APP_DATE',
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
			'appdate' => 'APP_DATE',
			},
		
		}; #test_addapp
	
	my $test_short_form_step1 = {
		
		1 => { 	'center' => '1',			'vtype' => '19',
			'persons' => '1',			'app_1_concil_free' => '0',
			'app_1_fname' => 'namefname',		'app_1_lname' => 'namelname',
			'app_1_passnum' => '0909AUTOTEST',	'app_1_citizenship' => '70',
			'app_1_bdate' => '11.11.1980',		'app_1_inlname' => 'фамилия',
			'app_1_infname' => 'имя',		'app_1_insname' => 'отчество',
			'apptime' => '1366',			'whom' => '1',
			'dovlname' => 'dovlname',		'dovfname' => 'dovfname',
			'dovsname' => 'dovsname',		'dovbdate' => '11.11.1980',
			'dovpassnum' => '0808AUTOTEST',		'dovpassdate' => '11.11.2010',
			'dovpasswhom' => 'ОВД',			'phone' => '3213232',
			'email' => 'email@email.com',		'address' => 'адрес',
			'shipnum' => '289',			'shaddress' => 'shaddress',
			'fdate' => 'START_DATE',		'edate' => 'END_DATE',
			'appdate' => 'APP_DATE',
			},
			
		2 => { 	'center' => '39',			'vtype' => '16',
			'persons' => '1',			'app_1_concil_free' => '1',
			'app_1_fname' => 'namefname',		'app_1_lname' => 'namelname',
			'app_1_passnum' => '0909AUTOTEST',	'app_1_citizenship' => '1',
			'app_1_bdate' => '11.11.1980',		'app_1_inlname' => 'фамилия',
			'app_1_infname' => 'имя',		'app_1_insname' => 'отчество',
			'apptime' => '880',			'whom' => '1',
			'dovlname' => 'dovlname',		'dovfname' => 'dovfname',
			'dovsname' => 'dovsname',		'dovbdate' => '11.11.1980',
			'dovpassnum' => '0808AUTOTEST',		'dovpassdate' => '11.11.2010',
			'dovpasswhom' => 'ОВД',			'phone' => '3213232',
			'email' => 'email@email.com',		'address' => 'адрес',
			'shipnum' => '289',			'shaddress' => 'shaddress',
			'fdate' => 'START_DATE',		'edate' => 'END_DATE',
			'appdate' => 'APP_DATE',
			},
			
		3 => { 	'center' => '29',			'vtype' => '13',
			'persons' => '1',			'app_1_concil_free' => '0',
			'app_1_fname' => 'namefname',		'app_1_lname' => 'namelname',
			'app_1_passnum' => '0909AUTOTEST',	'app_1_citizenship' => '19',
			'app_1_bdate' => '11.11.1980',		'app_1_inlname' => 'фамилия',
			'app_1_infname' => 'имя',		'app_1_insname' => 'отчество',
			'apptime' => '1023',			'whom' => '1',
			'dovlname' => 'dovlname',		'dovfname' => 'dovfname',
			'dovsname' => 'dovsname',		'dovbdate' => '11.11.1980',
			'dovpassnum' => '0808AUTOTEST',		'dovpassdate' => '11.11.2010',
			'dovpasswhom' => 'ОВД',			'phone' => '3213232',
			'email' => 'email@email.com',		'address' => 'адрес',
			'shipnum' => '289',			'shaddress' => 'shaddress',
			'fdate' => 'START_DATE',		'edate' => 'END_DATE',
			'appdate' => 'APP_DATE',
			},
		
		4 => { 	'center' => '61',			'vtype' => '10',
			'persons' => '1',			'app_1_concil_free' => '1',
			'app_1_fname' => 'namefname',		'app_1_lname' => 'namelname',
			'app_1_passnum' => '0909AUTOTEST',	'app_1_citizenship' => '30',
			'app_1_bdate' => '11.11.1980',		'app_1_inlname' => 'фамилия',
			'app_1_infname' => 'имя',		'app_1_insname' => 'отчество',
			'apptime' => '1200',			'whom' => '1',
			'dovlname' => 'dovlname',		'dovfname' => 'dovfname',
			'dovsname' => 'dovsname',		'dovbdate' => '11.11.1980',
			'dovpassnum' => '0808AUTOTEST',		'dovpassdate' => '11.11.2010',
			'dovpasswhom' => 'ОВД',			'phone' => '3213232',
			'email' => 'email@email.com',		'address' => 'адрес',
			'shipnum' => '289',			'shaddress' => 'shaddress',
			'fdate' => 'START_DATE',		'edate' => 'END_DATE',
			'appdate' => 'APP_DATE',
			},
		
		5 => { 	'center' => '53',			'vtype' => '7',
			'persons' => '1',			'app_1_concil_free' => '0',
			'app_1_fname' => 'namefname',		'app_1_lname' => 'namelname',
			'app_1_passnum' => '0909AUTOTEST',	'app_1_citizenship' => '98',
			'app_1_bdate' => '11.11.1980',		'app_1_inlname' => 'фамилия',
			'app_1_infname' => 'имя',		'app_1_insname' => 'отчество',
			'apptime' => '1291',			'whom' => '1',
			'dovlname' => 'dovlname',		'dovfname' => 'dovfname',
			'dovsname' => 'dovsname',		'dovbdate' => '11.11.1980',
			'dovpassnum' => '0808AUTOTEST',		'dovpassdate' => '11.11.2010',
			'dovpasswhom' => 'ОВД',			'phone' => '3213232',
			'email' => 'email@email.com',		'address' => 'адрес',
			'shipnum' => '289',			'shaddress' => 'shaddress',
			'fdate' => 'START_DATE',		'edate' => 'END_DATE',
			'appdate' => 'APP_DATE',
			},
		}; #test_short_form_step1
	
	my $test_short_form_step2 = {
		
		1 => { 	'whom1' => '1',				'center' => '1',
			'vtype' => '19',			'persons' => '1',
			'app_1_concil_free' => '0',		'app_1_fname' => 'namefname',
			'app_1_lname' => 'namelname',		'app_1_passnum' => '0909AUTOTEST',
			'app_1_citizenship' => '70',		'app_1_bdate' => '11.11.1980',
			'app_1_inlname' => 'фамилия',		'app_1_infname' => 'имя',
			'app_1_insname' => 'отчество',		'app_1_nres' => '0',
			'app_1_passin' => '0',			'whom' => '1',
			'shaddress' => 'shaddress',		'app_1_anketasrv' => '0',
			'app_1_anketasrv' => '0',		'app_1_photosrv' => '0',
			'shipping' => '1',			'needship' => '1',
			'sms' => '0',				'apptime' => '1366',
			'printsrv' => '0',			'dovlname' => 'dovlname',
			'dovfname' => 'dovfname',		'dovsname' => 'dovsname',
			'dovbdate' => '11.11.1980',		'dovpassnum' => '0808AUTOTEST',
			'dovpassdate' => '11.11.2010',		'dovpasswhom' => 'ОВД',
			'phone' => '3213232',			'email' => 'email@email.com',
			'address' => 'адрес',			'shipnum' => '289',
			'fdate' => 'START_DATE',		'edate' => 'END_DATE',
			'appdate' => 'APP_DATE',
			},
		
		2 => { 	'whom1' => '1',				'center' => '39',
			'vtype' => '16',			'persons' => '1',
			'app_1_concil_free' => '1',		'app_1_fname' => 'namefname',
			'app_1_lname' => 'namelname',		'app_1_passnum' => '0909AUTOTEST',
			'app_1_citizenship' => '1',		'app_1_bdate' => '11.11.1980',
			'app_1_inlname' => 'фамилия',		'app_1_infname' => 'имя',
			'app_1_insname' => 'отчество',		'app_1_nres' => '0',
			'app_1_passin' => '0',			'whom' => '1',
			'shaddress' => 'shaddress',		'app_1_anketasrv' => '0',
			'app_1_anketasrv' => '0',		'app_1_photosrv' => '0',
			'shipping' => '1',			'needship' => '1',
			'sms' => '0',				'apptime' => '880',
			'printsrv' => '0',			'dovlname' => 'dovlname',
			'dovfname' => 'dovfname',		'dovsname' => 'dovsname',
			'dovbdate' => '11.11.1980',		'dovpassnum' => '0808AUTOTEST',
			'dovpassdate' => '11.11.2010',		'dovpasswhom' => 'ОВД',
			'phone' => '3213232',			'email' => 'email@email.com',
			'address' => 'адрес',			'shipnum' => '289',
			'fdate' => 'START_DATE',		'edate' => 'END_DATE',
			'appdate' => 'APP_DATE',
			},
		
		3 => { 	'whom1' => '1',				'center' => '29',
			'vtype' => '13',			'persons' => '1',
			'app_1_concil_free' => '0',		'app_1_fname' => 'namefname',
			'app_1_lname' => 'namelname',		'app_1_passnum' => '0909AUTOTEST',
			'app_1_citizenship' => '19',		'app_1_bdate' => '11.11.1980',
			'app_1_inlname' => 'фамилия',		'app_1_infname' => 'имя',
			'app_1_insname' => 'отчество',		'app_1_nres' => '0',
			'app_1_passin' => '0',			'whom' => '1',
			'shaddress' => 'shaddress',		'app_1_anketasrv' => '0',
			'app_1_anketasrv' => '0',		'app_1_photosrv' => '0',
			'shipping' => '1',			'needship' => '1',
			'sms' => '0',				'apptime' => '1023',
			'printsrv' => '0',			'dovlname' => 'dovlname',
			'dovfname' => 'dovfname',		'dovsname' => 'dovsname',
			'dovbdate' => '11.11.1980',		'dovpassnum' => '0808AUTOTEST',
			'dovpassdate' => '11.11.2010',		'dovpasswhom' => 'ОВД',
			'phone' => '3213232',			'email' => 'email@email.com',
			'address' => 'адрес',			'shipnum' => '289',
			'fdate' => 'START_DATE',		'edate' => 'END_DATE',
			'appdate' => 'APP_DATE',
			},
		
		4 => { 	'whom1' => '1',				'center' => '61',
			'vtype' => '10',			'persons' => '1',
			'app_1_concil_free' => '1',		'app_1_fname' => 'namefname',
			'app_1_lname' => 'namelname',		'app_1_passnum' => '0909AUTOTEST',
			'app_1_citizenship' => '30',		'app_1_bdate' => '11.11.1980',
			'app_1_inlname' => 'фамилия',		'app_1_infname' => 'имя',
			'app_1_insname' => 'отчество',		'app_1_nres' => '0',
			'app_1_passin' => '0',			'whom' => '1',
			'shaddress' => 'shaddress',		'app_1_anketasrv' => '0',
			'app_1_anketasrv' => '0',		'app_1_photosrv' => '0',
			'shipping' => '1',			'needship' => '1',
			'sms' => '0',				'apptime' => '1200',
			'printsrv' => '0',			'dovlname' => 'dovlname',
			'dovfname' => 'dovfname',		'dovsname' => 'dovsname',
			'dovbdate' => '11.11.1980',		'dovpassnum' => '0808AUTOTEST',
			'dovpassdate' => '11.11.2010',		'dovpasswhom' => 'ОВД',
			'phone' => '3213232',			'email' => 'email@email.com',
			'address' => 'адрес',			'shipnum' => '289',
			'fdate' => 'START_DATE',		'edate' => 'END_DATE',
			'appdate' => 'APP_DATE',
			},
		
		5 => { 	'whom1' => '1',				'center' => '53',
			'vtype' => '7',				'persons' => '1',
			'app_1_concil_free' => '0',		'app_1_fname' => 'namefname',
			'app_1_lname' => 'namelname',		'app_1_passnum' => '0909AUTOTEST',
			'app_1_citizenship' => '98',		'app_1_bdate' => '11.11.1980',
			'app_1_inlname' => 'фамилия',		'app_1_infname' => 'имя',
			'app_1_insname' => 'отчество',		'app_1_nres' => '0',
			'app_1_passin' => '0',			'whom' => '1',
			'shaddress' => 'shaddress',		'app_1_anketasrv' => '0',
			'app_1_anketasrv' => '0',		'app_1_photosrv' => '0',
			'shipping' => '1',			'needship' => '1',
			'sms' => '0',				'apptime' => '1291',
			'printsrv' => '0',			'dovlname' => 'dovlname',
			'dovfname' => 'dovfname',		'dovsname' => 'dovsname',
			'dovbdate' => '11.11.1980',		'dovpassnum' => '0808AUTOTEST',
			'dovpassdate' => '11.11.2010',		'dovpasswhom' => 'ОВД',
			'phone' => '3213232',			'email' => 'email@email.com',
			'address' => 'адрес',			'shipnum' => '289',
			'fdate' => 'START_DATE',		'edate' => 'END_DATE',
			'appdate' => 'APP_DATE',
			},
		}; #test_short_form_step2
	
	my $test_contract = {
		
		1 => { 	
			'address' => 'городулица',		'sessionDuration' => '3635958',
			'visa' => '10',				'emptyBankid' => 'on',
			'sms' => '0',				'shipping' => '0',
			'shipnum' => '',			'ptype' => '1',
			'xerox' => '',				'inssum' => '',
			'anketasrv' => '',			'printsrv' => '',
			'req_1_visaType' => 'C',		'req_1_travelPurp' => 'TU',
			'req_1_duration' => '30',		'req_1_FirstEntry' => 'DK',
			'req_1_IBorderEntry' => '4',		'req_1_CBorderEntry' => 'wefwqfwqef',
			'req_1_MainDst' => 'I',			'req_1_CityDst' => 'wqfwqfwq',
			'req_1_numEntries' => 'M',		'req_1_startTravel' => 'START_DATE',
			'req_1_endTravel' => 'END_DATE',	'mpers' => 'APPLID',
			'ipers-APPLID' => 'APPLID',		'pass-APPLID' => '',
			'passdate-APPLID' => '',		'passwhom-APPLID' => '',
			'bdate-APPLID' => '21.02.1960',		'flydate-APPLID' => 'START_DATE',
			'lname-APPLID' => 'Фамилия',		'fname-APPLID' => 'Имя',
			'mname-APPLID' => 'Отчество',		'request-APPLID' => '1',
			'reqnumber' => '1',			'rqVisaType' => 'C',
			'rqTravelPurp' => 'TU',			'rqNumEntries' => 'M',
			'rqDuration' => '30',			'rqStartTravel' => 'START_DATE',
			'rqEndTravel' => 'END_DATE',		'rqFirstEntry' => 'DK',
			'rqIBorderEntry' => '4',		'rqCBorderEntry' => 'wefwqfwqef',
			'rqMainDst' => 'I',			'rqCityDst' => 'wqfwqfwq',
			'asnum-APPLID' => '',			'mlname' => 'Фамилия',
			'mfname' => 'Имя',			'mmname' => 'Отчество',
			'mpass' => '101010AUTOTEST',		'mpassdate' => '11.11.2010',
			'mpasswhom' => 'ОВД',			'phone' => '89117889373',
			'concilDate' => 'CONCIL_DATE',
			},
			
		2 => { 	
			'address' => 'городулица',		'sessionDuration' => '3635958',
			'visa' => '16',				'emptyBankid' => 'on',
			'sms' => '0',				'shipping' => '0',
			'shipnum' => '',			'ptype' => '1',
			'xerox' => '',				'inssum' => '',
			'anketasrv' => '',			'printsrv' => '',
			'req_1_visaType' => 'C',		'req_1_travelPurp' => 'TU',
			'req_1_duration' => '60',		'req_1_FirstEntry' => 'DK',
			'req_1_IBorderEntry' => '4',		'req_1_CBorderEntry' => 'wefwqfwqef',
			'req_1_MainDst' => 'I',			'req_1_CityDst' => 'wqfwqfwq',
			'req_1_numEntries' => 'M',		'req_1_startTravel' => 'START_DATE',
			'req_1_endTravel' => 'END_DATE',	'mpers' => 'APPLID',
			'ipers-APPLID' => 'APPLID',		'pass-APPLID' => '',
			'passdate-APPLID' => '',		'passwhom-APPLID' => '',
			'bdate-APPLID' => '21.02.1960',		'flydate-APPLID' => 'START_DATE',
			'lname-APPLID' => 'Фамилия',		'fname-APPLID' => 'Имя',
			'mname-APPLID' => 'Отчество',		'request-APPLID' => '1',
			'reqnumber' => '1',			'rqVisaType' => 'C',
			'rqTravelPurp' => 'TU',			'rqNumEntries' => 'M',
			'rqDuration' => '60',			'rqStartTravel' => 'START_DATE',
			'rqEndTravel' => 'END_DATE',		'rqFirstEntry' => 'DK',
			'rqIBorderEntry' => '4',		'rqCBorderEntry' => 'wefwqfwqef',
			'rqMainDst' => 'I',			'rqCityDst' => 'wqfwqfwq',
			'asnum-APPLID' => '',			'mlname' => 'Фамилия',
			'mfname' => 'Имя',			'mmname' => 'Отчество',
			'mpass' => '101010AUTOTEST',		'mpassdate' => '11.11.2010',
			'mpasswhom' => 'ОВД',			'phone' => '89117889373',
			'concilDate' => 'CONCIL_DATE',
			},
			
		3 => { 	
			'address' => 'городулица',		'sessionDuration' => '3635958',
			'visa' => '13',				'emptyBankid' => 'on',
			'sms' => '0',				'shipping' => '0',
			'shipnum' => '',			'ptype' => '1',
			'xerox' => '',				'inssum' => '',
			'anketasrv' => '',			'printsrv' => '',
			'req_1_visaType' => 'C',		'req_1_travelPurp' => 'TU',
			'req_1_duration' => '90',		'req_1_FirstEntry' => 'DK',
			'req_1_IBorderEntry' => '4',		'req_1_CBorderEntry' => 'wefwqfwqef',
			'req_1_MainDst' => 'I',			'req_1_CityDst' => 'wqfwqfwq',
			'req_1_numEntries' => 'M',		'req_1_startTravel' => 'START_DATE',
			'req_1_endTravel' => 'END_DATE',	'mpers' => 'APPLID',
			'ipers-APPLID' => 'APPLID',		'pass-APPLID' => '',
			'passdate-APPLID' => '',		'passwhom-APPLID' => '',
			'bdate-APPLID' => '21.02.1960',		'flydate-APPLID' => 'START_DATE',
			'lname-APPLID' => 'Фамилия',		'fname-APPLID' => 'Имя',
			'mname-APPLID' => 'Отчество',		'request-APPLID' => '1',
			'reqnumber' => '1',			'rqVisaType' => 'C',
			'rqTravelPurp' => 'TU',			'rqNumEntries' => 'M',
			'rqDuration' => '90',			'rqStartTravel' => 'START_DATE',
			'rqEndTravel' => 'END_DATE',		'rqFirstEntry' => 'DK',
			'rqIBorderEntry' => '4',		'rqCBorderEntry' => 'wefwqfwqef',
			'rqMainDst' => 'I',			'rqCityDst' => 'wqfwqfwq',
			'asnum-APPLID' => '',			'mlname' => 'Фамилия',
			'mfname' => 'Имя',			'mmname' => 'Отчество',
			'mpass' => '101010AUTOTEST',		'mpassdate' => '11.11.2010',
			'mpasswhom' => 'ОВД',			'phone' => '89117889373',
			'concilDate' => 'CONCIL_DATE',
			},
		
		4 => { 	
			'address' => 'городулица',		'sessionDuration' => '3635958',
			'visa' => '10',				'emptyBankid' => 'on',
			'sms' => '0',				'shipping' => '0',
			'shipnum' => '',			'ptype' => '1',
			'xerox' => '',				'inssum' => '',
			'anketasrv' => '',			'printsrv' => '',
			'req_1_visaType' => 'C',		'req_1_travelPurp' => 'TU',
			'req_1_duration' => '120',		'req_1_FirstEntry' => 'DK',
			'req_1_IBorderEntry' => '4',		'req_1_CBorderEntry' => 'wefwqfwqef',
			'req_1_MainDst' => 'I',			'req_1_CityDst' => 'wqfwqfwq',
			'req_1_numEntries' => 'M',		'req_1_startTravel' => 'START_DATE',
			'req_1_endTravel' => 'END_DATE',	'mpers' => 'APPLID',
			'ipers-APPLID' => 'APPLID',		'pass-APPLID' => '',
			'passdate-APPLID' => '',		'passwhom-APPLID' => '',
			'bdate-APPLID' => '21.02.1960',		'flydate-APPLID' => 'START_DATE',
			'lname-APPLID' => 'Фамилия',		'fname-APPLID' => 'Имя',
			'mname-APPLID' => 'Отчество',		'request-APPLID' => '1',
			'reqnumber' => '1',			'rqVisaType' => 'C',
			'rqTravelPurp' => 'TU',			'rqNumEntries' => 'M',
			'rqDuration' => '120',			'rqStartTravel' => 'START_DATE',
			'rqEndTravel' => 'END_DATE',		'rqFirstEntry' => 'DK',
			'rqIBorderEntry' => '4',		'rqCBorderEntry' => 'wefwqfwqef',
			'rqMainDst' => 'I',			'rqCityDst' => 'wqfwqfwq',
			'asnum-APPLID' => '',			'mlname' => 'Фамилия',
			'mfname' => 'Имя',			'mmname' => 'Отчество',
			'mpass' => '101010AUTOTEST',		'mpassdate' => '11.11.2010',
			'mpasswhom' => 'ОВД',			'phone' => '89117889373',
			'concilDate' => 'CONCIL_DATE',
			},
		
		5 => { 	
			'address' => 'городулица',		'sessionDuration' => '3635958',
			'visa' => '7',				'emptyBankid' => 'on',
			'sms' => '0',				'shipping' => '0',
			'shipnum' => '',			'ptype' => '1',
			'xerox' => '',				'inssum' => '',
			'anketasrv' => '',			'printsrv' => '',
			'req_1_visaType' => 'C',		'req_1_travelPurp' => 'TU',
			'req_1_duration' => '150',		'req_1_FirstEntry' => 'DK',
			'req_1_IBorderEntry' => '4',		'req_1_CBorderEntry' => 'wefwqfwqef',
			'req_1_MainDst' => 'I',			'req_1_CityDst' => 'wqfwqfwq',
			'req_1_numEntries' => 'M',		'req_1_startTravel' => 'START_DATE',
			'req_1_endTravel' => 'END_DATE',	'mpers' => 'APPLID',
			'ipers-APPLID' => 'APPLID',		'pass-APPLID' => '',
			'passdate-APPLID' => '',		'passwhom-APPLID' => '',
			'bdate-APPLID' => '21.02.1960',		'flydate-APPLID' => 'START_DATE',
			'lname-APPLID' => 'Фамилия',		'fname-APPLID' => 'Имя',
			'mname-APPLID' => 'Отчество',		'request-APPLID' => '1',
			'reqnumber' => '1',			'rqVisaType' => 'C',
			'rqTravelPurp' => 'TU',			'rqNumEntries' => 'M',
			'rqDuration' => '150',			'rqStartTravel' => 'START_DATE',
			'rqEndTravel' => 'END_DATE',		'rqFirstEntry' => 'DK',
			'rqIBorderEntry' => '4',		'rqCBorderEntry' => 'wefwqfwqef',
			'rqMainDst' => 'I',			'rqCityDst' => 'wqfwqfwq',
			'asnum-APPLID' => '',			'mlname' => 'Фамилия',
			'mfname' => 'Имя',			'mmname' => 'Отчество',
			'mpass' => '101010AUTOTEST',		'mpassdate' => '11.11.2010',
			'mpasswhom' => 'ОВД',			'phone' => '89117889373',
			'concilDate' => 'CONCIL_DATE',
			},
		}; #test_contract
	
	my $db_connect = VCS::Config->getConfig();

	my $r = $vars->db->query("
			CREATE TABLE Autotest (ID INT NOT NULL AUTO_INCREMENT,
			Test VARCHAR(6), Param VARCHAR(50), Value VARCHAR(256), PRIMARY KEY (ID))", {});

	# TT	
	for (@$tt_adr_default) {
		my $r = $vars->db->query("
			INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)", 
			{}, 'test9', 'page_adr', $_); };
	
	default_config($vars, 'test9', ['settings_test_ref', 'settings_test_404']);
	
	# TS
	
	for (@$ts_centers) {
		my $r = $vars->db->query("
			INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
			{}, 'test1', 'centers', $_); };
	
	default_config($vars, 'test1', {'settings_test_null' => 1, 'settings_test_error' => 1, 'day_slots_test' => 10, 'far_far_day' => 1});
	
	# SQL
	
	default_config($vars, 'test7', ['settings_test_select', 'settings_test_insert', 'settings_test_update']);
	
	# MT
	for (@$modul_tests) {
		my $r = $vars->db->query("
			INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
			{}, 'test5', $_, 1); };
	
	# UP
	
	default_config($vars, 'test11', {'settings_test_oldlist' => 1, 'settings_test_difeuro' => 1, 
		'settings_test_difper' => 5, 'settings_test_difday' => 0});
	
	# SY
	
	default_config($vars, 'test10', ['settings_perlc']);
	
	# TR
	
	default_config($vars, 'test6', ['settings_rb_langreq', 'settings_rb_comm', 'settings_dict_langreq', 'settings_dict_getLangVar']);
	
	# RP
	
	for (@$report_name) {
		my $r = $vars->db->query("
			INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
			{}, 'test4', $_, 1);
			};
	
	default_config($vars, 'test4', ['settings_format_pdf', 'settings_format_zip', 'settings_format_xml']);
	
	# AA
	
	for my $test ( keys %$test_addapp ) {
		for my $param ( keys %{$test_addapp->{$test}} ) {
			my $r = $vars->db->query("
				INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
				{}, 'test3', $test.':'.$param, $test_addapp->{$test}->{$param} ); 
			}; 
		my $r = $vars->db->query("
				INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
				{}, 'test3', 'settings_collect_name_'.$test, 'встроенный набор параметров '.$test ); 
		};
	
	default_config($vars, 'test3', {'settings_collect_num' => scalar(keys %$test_addapp), 'settings_autodate' => 1, 
		'settings_fixdate' => '',});
	
	# SF
	
	for my $test ( keys %$test_short_form_step1 ) {
		for my $param ( keys %{$test_short_form_step1->{$test}} ) {
			my $r = $vars->db->query("
				INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
				{}, 'test2A', $test.':'.$param, $test_short_form_step1->{$test}->{$param} ); 
			}; 
		my $r = $vars->db->query("
				INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
				{}, 'test2', 'settings_collect_name_'.$test, 'встроенный набор параметров '.$test ); 
		};

	for my $test ( keys %$test_short_form_step2 ) {
		for my $param ( keys %{$test_short_form_step2->{$test}} ) {
			my $r = $vars->db->query("
				INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
				{}, 'test2B', $test.':'.$param, $test_short_form_step2->{$test}->{$param} ); 
			};  
		};
	
	default_config($vars, 'test2', { 'settings_collect_num' => scalar(keys %$test_short_form_step1), 'settings_autodate' => 1, 
		'settings_appdate' => '', 'settings_fixdate_s' => '', 'settings_fixdate_e' => '',});
	
	# TC
	for my $test ( keys %$test_contract ) {
		for my $param ( keys %{$test_contract->{$test}} ) {
			my $r = $vars->db->query("
				INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
				{}, 'test8', $test.':'.$param, $test_contract->{$test}->{$param} ); 
			};  
		
		my $r = $vars->db->query("
				INSERT INTO Autotest (Test,Param,Value) VALUES (?,?,?)",
				{}, 'test8', 'settings_collect_name_'.$test, 'встроенный набор параметров '.$test ); 
		};
	
	default_config($vars, 'test8', {'settings_collect_num' => scalar(keys %$test_contract), 'settings_fixdate_s' => '', 
		'settings_fixdate_e' => '', 'settings_concildate' => '', 'settings_autodate' => 1,});
		
	return 1;	
	}

1;
