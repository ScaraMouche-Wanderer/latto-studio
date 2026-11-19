#!/usr/bin/python
"""Native, local settings companion for Latto."""
import sys,os,json,argparse
from pathlib import Path
from PySide6.QtCore import Qt,QTimer,QSize,QProcess,QUrl,QSignalBlocker
from PySide6.QtGui import QColor,QFont,QDesktopServices,QIcon,QShortcut,QKeySequence
from PySide6.QtWidgets import (QApplication,QMainWindow,QWidget,QVBoxLayout,QHBoxLayout,
    QGridLayout,QLabel,QPushButton,QListWidget,QListWidgetItem,QStackedWidget,QScrollArea,
    QFrame,QFormLayout,QLineEdit,QColorDialog,QComboBox,QSlider,QSpinBox,QCheckBox,
    QAbstractItemView,QFontComboBox,QMessageBox,QFileDialog,QInputDialog,QCompleter,
    QButtonGroup,QSizePolicy,QBoxLayout)
from model import DEFAULTS,PRESETS,CINEMA_NOTES,TABS,ITEMS,LAYOUTS,ConfigStore,Profiles,validate,effective_width
from widgets import Preview,Toggle,NavigationDelegate,PaletteTile

PAGES=['Appearance','Compact layout','Tabs & order','Behaviour','Focus & alerts','Profiles & backups']

class Studio(QMainWindow):
    def __init__(self,config=None,backups=None,monitor=True,*,demo=False):
        super().__init__()
        self.demo=demo
        self.setWindowTitle('Latto Studio')
        self.setWindowIcon(QIcon(str(Path(__file__).with_name('icon.svg'))))
        self.resize(1280,860);self.setMinimumSize(880,660)
        home=Path.home()
        config=config or Path(os.environ.get('XDG_CONFIG_HOME',home/'.config'))/'latto/config.json'
        backups=backups or home/'.local/share/latto-studio/backups'
        self.store=ConfigStore(config,backups)
        self.profiles=Profiles(self.store.backups.parent/'profiles')
        self.pending=False;self.loading=True;self.last_mtime=self.mtime()
        self.controls={};self.colors={};self.swatches={};self.search_entries={};self.preset_buttons={}
        self.debounce=QTimer(self);self.debounce.setSingleShot(True);self.debounce.setInterval(450);self.debounce.timeout.connect(self.apply)
        main=QWidget();main.setObjectName('root');self.setCentralWidget(main)
        outer=QHBoxLayout(main);outer.setContentsMargins(0,0,0,0);outer.setSpacing(0)
        sidebar=QFrame();sidebar.setObjectName('sidebar');sidebar.setFixedWidth(190)
        side=QVBoxLayout(sidebar);side.setContentsMargins(16,28,16,20);side.setSpacing(12)
        logo=QLabel();logo.setPixmap(QIcon(str(Path(__file__).with_name('icon.svg'))).pixmap(34,34));side.addWidget(logo)
        brand=QLabel('latto');brand.setObjectName('brand');side.addWidget(brand)
        tagline=QLabel('STUDIO');tagline.setObjectName('wordmarkNote');side.addWidget(tagline)
        self.nav=QListWidget();self.nav.setObjectName('navigation');self.nav.setSpacing(3);self.nav.setItemDelegate(NavigationDelegate(self.nav));self.nav.setMouseTracking(True);self.nav.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        for i,name in enumerate(PAGES):
            item=QListWidgetItem(name);item.setSizeHint(QSize(154,45));self.nav.addItem(item)
        side.addWidget(self.nav,1)
        local=QLabel('Ctrl K   Search\nCtrl S   Apply');local.setObjectName('sideNote');side.addWidget(local)
        self.connection=QLabel('●  DEMO SESSION' if demo else '●  LOCAL SETTINGS');self.connection.setObjectName('badge');self.connection.setToolTip('Settings file: '+str(self.store.path));side.addWidget(self.connection)
        outer.addWidget(sidebar)
        area=QWidget();body=QVBoxLayout(area);body.setContentsMargins(26,22,26,18);body.setSpacing(16);outer.addWidget(area,1)
        header=QHBoxLayout();titles=QVBoxLayout();titles.setSpacing(5)
        self.section_number=QLabel('01 / APPEARANCE');self.section_number.setObjectName('pageIndex');titles.addWidget(self.section_number)
        self.editor_title=QLabel('Material & colour');self.editor_title.setObjectName('title');titles.addWidget(self.editor_title)
        header.addLayout(titles,1)
        self.search=QLineEdit();self.search.setObjectName('search');self.search.setPlaceholderText('Search settings   Ctrl K');self.search.setFixedWidth(205);self.search.setClearButtonEnabled(True);self.search.setAccessibleName('Search settings');header.addWidget(self.search)
        self.preview_toggle=QPushButton('Viewfinder');self.preview_toggle.setCheckable(True);self.preview_toggle.setChecked(True);self.preview_toggle.setToolTip('Show or hide the island preview.');header.addWidget(self.preview_toggle)
        body.addLayout(header)
        self.workspace=QBoxLayout(QBoxLayout.LeftToRight);self.workspace.setSpacing(20);body.addLayout(self.workspace,1)
        self.pages=QStackedWidget();self.pages.setMinimumWidth(0);self.workspace.addWidget(self.pages,1)
        preview_card=QFrame();self.preview_card=preview_card;preview_card.setObjectName('previewCard');pv=QVBoxLayout(preview_card);pv.setContentsMargins(14,15,14,14);pv.setSpacing(12)
        preview_header=QHBoxLayout();self.preview_caption=QLabel('SAMPLE · COMPACT');self.preview_caption.setObjectName('eyebrow');preview_header.addWidget(self.preview_caption);preview_header.addStretch()
        mark=QLabel('VIEWFINDER');mark.setObjectName('eyebrow');preview_header.addWidget(mark);pv.addLayout(preview_header)
        modes=QHBoxLayout();modes.setSpacing(2);self.preview_modes=QButtonGroup(self)
        for mode in ['Compact','Music','Expanded']:
            button=QPushButton(mode);button.setCheckable(True);button.setObjectName('segment');button.setChecked(mode=='Compact');button.setCursor(Qt.PointingHandCursor);button.setAccessibleName(mode+' sample preview');self.preview_modes.addButton(button);modes.addWidget(button)
            button.toggled.connect(lambda checked,m=mode:self.set_preview_mode(m) if checked else None)
        pv.addLayout(modes);self.preview=Preview();pv.addWidget(self.preview)
        self.preview_details=QWidget();details=QVBoxLayout(self.preview_details);details.setContentsMargins(0,0,0,0);details.setSpacing(14)
        stages=QHBoxLayout();stages.setSpacing(5);self.stage_buttons=QButtonGroup(self)
        for name in ['Paper','Slate','Night']:
            button=QPushButton(name);button.setCheckable(True);button.setObjectName('stageChip');button.setChecked(name=='Paper');button.setCursor(Qt.PointingHandCursor);button.setToolTip('Preview backdrop only; your wallpaper stays unchanged.');self.stage_buttons.addButton(button);stages.addWidget(button)
            button.toggled.connect(lambda checked,n=name:self.preview.set_stage(n) if checked else None)
        details.addLayout(stages)
        specs=QHBoxLayout();size_box=QVBoxLayout();size_label=QLabel('COMPACT WIDTH');size_label.setObjectName('eyebrow');size_box.addWidget(size_label)
        self.dimension_readout=QLabel();self.dimension_readout.setObjectName('specValue');size_box.addWidget(self.dimension_readout);specs.addLayout(size_box,1)
        self.finish_readout=QLabel();self.finish_readout.setAlignment(Qt.AlignRight|Qt.AlignVCenter);self.finish_readout.setObjectName('specSummary');specs.addWidget(self.finish_readout);details.addLayout(specs)
        self.preview_note=QLabel('Battery and statistics use local readings. The Expanded sample matches the Summary layout in Tabs & order.');self.preview_note.setObjectName('previewNote');self.preview_note.setWordWrap(True);details.addWidget(self.preview_note)
        self.show_island=self.button('Show current island',lambda:self.control('open'))
        self.show_island.setObjectName('showCurrentIsland')
        self.show_island.setToolTip('Open the island on your desktop. Apply any draft changes first to see them there.')
        current_config=Path(os.environ.get('XDG_CONFIG_HOME',home/'.config'))/'latto/config.json'
        self.show_island.setEnabled(self.store.path.resolve()==current_config.resolve())
        self.show_island.setVisible(not demo)
        details.addWidget(self.show_island)
        pv.addWidget(self.preview_details);pv.addStretch(1)
        self.workspace.addWidget(preview_card)
        self.preview_toggle.toggled.connect(self.preview_card.setVisible)
        self.nav.currentRowChanged.connect(self.pages.setCurrentIndex);self.nav.currentRowChanged.connect(self.update_section)
        self.appearance_page();self.compact_page();self.tabs_page();self.behaviour_page();self.focus_page();self.profiles_page();self.nav.setCurrentRow(0)
        self.update_workspace()
        completer=QCompleter(list(self.search_entries),self);completer.setCaseSensitivity(Qt.CaseInsensitive);completer.setFilterMode(Qt.MatchContains);completer.setCompletionMode(QCompleter.PopupCompletion);completer.activated.connect(self.find_setting);self.search.setCompleter(completer);self.search.returnPressed.connect(self.find_first)
        footer=QFrame();footer.setObjectName('footer');foot=QVBoxLayout(footer);foot.setContentsMargins(0,10,0,0);foot.setSpacing(8)
        self.status=QLabel('Saved on this device');self.status.setWordWrap(True);self.status.setObjectName('status');foot.addWidget(self.status)
        actions=QHBoxLayout();self.live=Toggle('Apply changes live');self.live.setChecked(True);self.live.setToolTip('Save automatically after you change a control. Turn off to preview a draft.');self.live.toggled.connect(self.live_changed);actions.addWidget(self.live);actions.addStretch()
        self.undo=QPushButton('Undo session');self.undo.clicked.connect(self.undo_changes);self.undo.setToolTip('Restore settings from when this Studio window opened.');actions.addWidget(self.undo)
        self.apply_button=QPushButton('Apply changes');self.apply_button.setObjectName('apply');self.apply_button.clicked.connect(self.apply);actions.addWidget(self.apply_button);foot.addLayout(actions);body.addWidget(footer)
        self.load(self.store.read());self.loading=False
        self.process=QProcess(self);self.process.finished.connect(self.probe_finished);self.process.errorOccurred.connect(lambda error:self.connection.setText('○  STATUS UNAVAILABLE'))
        self.probe_timer=QTimer(self);self.probe_timer.setInterval(10000);self.probe_timer.timeout.connect(self.probe)
        self.probe_timeout=QTimer(self);self.probe_timeout.setSingleShot(True);self.probe_timeout.setInterval(3000);self.probe_timeout.timeout.connect(self.process.kill)
        self.control_process=QProcess(self);self.control_process.finished.connect(self.control_finished);self.control_process.errorOccurred.connect(lambda error:self.message('Could not start the Latto launcher.',True))
        self.file_timer=QTimer(self);self.file_timer.setInterval(1000);self.file_timer.timeout.connect(self.external_change);self.file_timer.start()
        for key,callback in [('Ctrl+K',self.search.setFocus),('Ctrl+S',self.apply),('Escape',self.clear_search)]:
            shortcut=QShortcut(QKeySequence(key),self);shortcut.activated.connect(callback)
        if monitor and not demo:self.probe_timer.start();QTimer.singleShot(0,self.probe)

    def update_section(self,index):
        names=['Material & colour','At a glance','Tools & sequence','Interaction','Focus & signals','Your collection']
        if 0<=index<len(names):
            self.section_number.setText(f'{index+1:02} / '+PAGES[index].upper())
            self.editor_title.setText(names[index])

    def update_workspace(self):
        if not hasattr(self,'workspace'):return
        wide=self.width()>=1140
        self.workspace.setDirection(QBoxLayout.LeftToRight if wide else QBoxLayout.BottomToTop)
        self.preview_card.setMinimumWidth(342 if wide else 0)
        self.preview_card.setMaximumWidth(342 if wide else 16777215)
        self.preview_card.setMaximumHeight(16777215 if wide else 230)
        self.preview.setMinimumHeight(250 if wide else 126)
        self.preview.setMaximumHeight(300 if wide else 126)
        self.preview_details.setVisible(wide)

    def resizeEvent(self,event):
        super().resizeEvent(event)
        self.update_workspace()

    def set_preview_mode(self,mode):
        self.preview.set_mode(mode)
        self.preview_caption.setText('SAMPLE · '+mode.upper())
        self.preview_toggle.setChecked(True)

    def page(self,title,description):
        wrap=QWidget();layout=QVBoxLayout(wrap);layout.setContentsMargins(1,0,10,6);layout.setSpacing(14)
        heading=QLabel(title);heading.setObjectName('section');layout.addWidget(heading)
        desc=QLabel(description);desc.setObjectName('muted');desc.setWordWrap(True);layout.addWidget(desc)
        scroll=QScrollArea();scroll.setWidgetResizable(True);scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff);scroll.setWidget(wrap);self.pages.addWidget(scroll)
        return layout

    def card(self,page,title,description=''):
        frame=QFrame();frame.setObjectName('card');box=QVBoxLayout(frame);box.setContentsMargins(16,15,16,17);box.setSpacing(12)
        label=QLabel(title);label.setObjectName('cardTitle');box.addWidget(label)
        if description:
            note=QLabel(description);note.setObjectName('muted');note.setWordWrap(True);box.addWidget(note)
        form=QFormLayout();form.setHorizontalSpacing(24);form.setVerticalSpacing(12);form.setFieldGrowthPolicy(QFormLayout.AllNonFixedFieldsGrow);form.setRowWrapPolicy(QFormLayout.WrapLongRows);box.addLayout(form);page.addWidget(frame)
        return form

    def row(self,form,label,widget,keywords=''):
        form.addRow(label,widget)
        if label:self.search_entries[label+(' · '+keywords if keywords else '')]=(self.pages.count()-1,widget)

    def button(self,text,callback,primary=False):
        b=QPushButton(text);b.setCursor(Qt.PointingHandCursor);b.clicked.connect(callback)
        if primary:b.setObjectName('apply')
        return b

    def appearance_page(self):
        page=self.page('Palette library','Quiet materials and cinematic motion. Preview a theme, then tune its effect.')
        form=self.card(page,'01   /   Collection')
        grid=QGridLayout();grid.setSpacing(8)
        for i,(name,values) in enumerate(PRESETS.items()):
            b=PaletteTile(name,values)
            if name in CINEMA_NOTES:b.setToolTip(CINEMA_NOTES[name])
            b.clicked.connect(lambda checked=False,n=name:self.use_preset(n));grid.addWidget(b,i//4,i%4);self.preset_buttons[name]=b
        form.addRow(grid)
        # Keep a keyboard-accessible combo as an alternative to the palette grid.
        self.preset=QComboBox();self.preset.addItems(['Custom / current',*PRESETS]);self.preset.currentTextChanged.connect(self.use_preset);self.row(form,'Palette',self.preset,'theme preset')
        form=self.card(page,'02   /   Living patterns','Background effects stay behind your controls. Reduced motion freezes the pattern; Off removes it.')
        self.choice(form,'Animated motif','ambientStyle',[
            ('Off · quiet background','off'),('Halloween · rising embers','embers'),
            ('Haunted · spectral fog','haunted'),('Prism · flowing rainbow','prism'),
            ('Odyssey · orbit & stars','odyssey'),('Arc reactor · rotating core','reactor'),
            ('Crimson · traveling web','web'),('Neon · electric waves','neon'),
            ('Aurora · flowing clouds','aurora'),('Solar · orbital flare','solar'),
            ('Candy · diagonal spectrum','candy')])
        self.spin(form,'Effect strength','ambientIntensity',0,80,100,' %')
        self.spin(form,'Flow speed','ambientSpeed',25,200,100,' %')
        form=self.card(page,'03   /   Custom colours')
        for key,label in [('accentColor','Accent'),('backgroundColor','Island background'),('surfaceColor','Cards & panels'),('textColor','Text')]:
            wrap=QWidget();line=QHBoxLayout(wrap);line.setContentsMargins(0,0,0,0);line.setSpacing(8)
            swatch=QPushButton();swatch.setFixedSize(36,36);swatch.setAccessibleName('Choose '+label.lower());swatch.clicked.connect(lambda checked=False,k=key:self.pick_color(k));self.swatches[key]=swatch
            edit=QLineEdit();edit.setMaxLength(7);edit.setPlaceholderText('#c4a7e7');edit.setAccessibleName(label+' hex colour');edit.textChanged.connect(self.changed);edit.setMaximumWidth(150);self.colors[key]=edit
            choose=self.button('Choose colour',lambda checked=False,k=key:self.pick_color(k));line.addWidget(swatch);line.addWidget(edit);line.addWidget(choose,1);self.row(form,label,wrap)
        self.contrast=QLabel();self.contrast.setWordWrap(True);self.contrast.setObjectName('muted');form.addRow(self.contrast)
        form=self.card(page,'04   /   Finish')
        self.choice(form,'Corners','cornerStyle',[('Classic pill','pill'),('Soft rounded','rounded')]);self.choice(form,'Motion','motionStyle',[('Smooth & flowing','smooth'),('Fast & snappy','snappy'),('Reduced motion','reduced')])
        self.spin(form,'Background opacity','backgroundOpacity',35,100,100,' %');self.spin(form,'Control borders','borderOpacity',0,40,100,' %')
        form.addRow(self.button('Reset appearance',self.reset_appearance));page.addStretch()

    def compact_page(self):
        page=self.page('Compact layout','Choose what you see at a glance, without opening the island.')
        form=self.card(page,'Start with a layout')
        chips=QHBoxLayout();chips.setSpacing(8)
        for name in LAYOUTS:chips.addWidget(self.button(name,lambda checked=False,n=name:self.use_layout(n)))
        form.addRow(chips)
        self.spin(form,'Preferred width','idleWidth',180,480,1,' px');self.spin(form,'Distance from top','topOffset',32,160,1,' px')
        self.width_note=QLabel();self.width_note.setObjectName('muted');self.width_note.setWordWrap(True);form.addRow(self.width_note)
        form=self.card(page,'At-a-glance indicators','Privacy and timer activity takes priority when the island is crowded.')
        self.item_checks={};grid=QGridLayout()
        for i,(key,label) in enumerate(ITEMS.items()):
            check=Toggle(label);check.toggled.connect(self.changed);self.item_checks[key]=check;grid.addWidget(check,i//2,i%2);self.search_entries[label]=(self.pages.count()-1,check)
        form.addRow(grid)
        form=self.card(page,'Clock & date')
        self.choice(form,'Clock format','clockFormat',[('24-hour · 21:30','24h'),('12-hour · 9:30 PM','12h')]);self.toggle(form,'Show seconds','showSeconds')
        self.choice(form,'Date format','dateFormat',[('Short · Thu 22','ddd d'),('Full · Thu, Oct 22','ddd, MMM d'),('Numeric · 22/10','dd/MM'),('Month · Oct 22','MMM d')]);self.toggle(form,'Battery percentage','batteryPercentage');page.addStretch()

    def tabs_page(self):
        page=self.page('Tabs & order','Choose your tools. Drag a tab or use the move buttons to set its position.')
        codex=self.card(page,'Codex assistant','Control whether Codex appears in the expanded island and whether its answer can be typed into the focused editor.')
        self.codex_section=Toggle('Show Codex section');self.codex_section.toggled.connect(self.codex_section_toggled);codex.addRow(self.codex_section)
        self.search_entries['Show Codex section']=(self.pages.count()-1,self.codex_section)
        self.toggle(codex,'Allow Codex to type answers','codexTypingEnabled')
        form=self.card(page,'Your expanded island')
        self.choice(form,'Expanded layout','expandedLayout',[('Full tabs','tabs'),('Summary · CPU, memory & battery','summary')])
        self.tab_count=QLabel();self.tab_count.setObjectName('muted');form.addRow(self.tab_count)
        self.tab_list=QListWidget();self.tab_list.setMinimumHeight(255);self.tab_list.setDragDropMode(QAbstractItemView.InternalMove);self.tab_list.setDefaultDropAction(Qt.MoveAction);self.tab_list.setAlternatingRowColors(False);self.tab_list.itemChanged.connect(self.tab_item_changed);self.tab_list.model().rowsMoved.connect(self.changed);form.addRow(self.tab_list)
        buttons=QHBoxLayout();buttons.setSpacing(8)
        for title,delta in [('↑  Move up',-1),('↓  Move down',1)]:buttons.addWidget(self.button(title,lambda checked=False,d=delta:self.move_tab(d)))
        form.addRow(buttons);form.addRow(self.button('Restore default tabs',self.reset_tabs));self.search_entries['Tab visibility and order']=(self.pages.count()-1,self.tab_list);page.addStretch()

    def codex_section_toggled(self,enabled):
        for row in range(self.tab_list.count()):
            item=self.tab_list.item(row)
            if item.data(Qt.UserRole)=='codex':
                item.setCheckState(Qt.Checked if enabled else Qt.Unchecked)
                return

    def tab_item_changed(self,item):
        if item.data(Qt.UserRole)=='codex':
            blocker=QSignalBlocker(self.codex_section)
            self.codex_section.setChecked(item.checkState()==Qt.Checked)
            del blocker
        self.changed()

    def behaviour_page(self):
        page=self.page('Behaviour','Tune how Latto responds to you and your music.')
        form=self.card(page,'Island presence','Keep time and battery visible in the small island. A deliberate hover opens your controls; moving away returns to the small island. Pinning and text entry keep controls open.')
        self.toggle(form,'Always show the small island','compactAlwaysVisible')
        self.toggle(form,'Attach to top edge with sloping sides','edgeReveal')
        self.spin(form,'Hover before expanding','hoverExpandDelay',140,1000,1,' ms')
        self.controls['hoverExpandDelay'][0].setSingleStep(20)
        self.spin(form,'Wait before closing','hoverCloseDelay',180,1000,1,' ms')
        self.controls['hoverCloseDelay'][0].setSingleStep(20)
        self.controls['hoverCloseDelay'][0].setToolTip('Grace period after the pointer leaves, before the island folds back.')
        form=self.card(page,'Interaction & music')
        self.toggle(form,'Calendar events from khal','calendarEnabled');self.toggle(form,'Expand on hover','hoverToExpand');self.toggle(form,'Keep playing music visible','mediaAlwaysShown');self.spin(form,'Track announcement','nowPlayingDuration',1000,12000,1,' ms')
        form=self.card(page,'Clipboard history','Text, links and small images stay on this device across logout. File copies save references, not the original files. Pause and delete controls are in the Clipboard tab.')
        self.toggle(form,'Save clipboard history','clipboardEnabled')
        self.spin(form,'Recent copies to retain','clipboardHistoryLimit',50,100,1,' items')
        self.controls['clipboardHistoryLimit'][0].setSingleStep(50)
        form=self.card(page,'Typography & sampling')
        self.font=QFontComboBox();self.font.currentFontChanged.connect(self.changed)
        self.font_system=Toggle('Use system font')
        self.font_system.toggled.connect(self.system_font_changed)
        form.addRow(self.font_system)
        self.search_entries['Use system font']=(self.pages.count()-1,self.font_system)
        self.row(form,'Island font',self.font)
        self.spin(form,'Statistics refresh','statsInterval',1000,10000,1,' ms')
        note=QLabel('A longer refresh interval reduces background sampling.');note.setObjectName('muted');note.setWordWrap(True);form.addRow(note)
        form=self.card(page,'Island controls','The demo uses a temporary settings file.' if self.demo else 'Settings keep working after you close Studio.')
        if not self.demo:
            buttons=QHBoxLayout();buttons.setSpacing(8)
            for text,action in [('Start', 'start'),('Stop','stop'),('Restart','restart')]:buttons.addWidget(self.button(text,lambda checked=False,a=action:self.control(a)))
            form.addRow(buttons)
        form.addRow(self.button('Reload saved settings',self.reload_saved));page.addStretch()

    def focus_page(self):
        page=self.page('Focus & alerts','Make focus sessions and everyday signals work for you.')
        form=self.card(page,'Focus timer','New durations are used when the next phase starts.')
        self.spin(form,'Focus session','pomodoroFocusMinutes',1,180,1,' min');self.spin(form,'Short break','pomodoroBreakMinutes',1,60,1,' min');self.spin(form,'Long break','pomodoroLongBreakMinutes',1,120,1,' min');self.spin(form,'Sessions before long break','pomodoroRounds',1,12)
        self.toggle(form,'Latto Do Not Disturb during focus','pomodoroDnd');self.toggle(form,'Timer completion sound','timerSound')
        form=self.card(page,'Everyday indicators')
        self.toggle(form,'Microphone & camera indicators','privacyIndicators');self.toggle(form,'Caps Lock indicator','capsLockIndicator');self.toggle(form,'Bluetooth connection alerts','bluetoothAlerts');self.spin(form,'Low battery warning','lowBatteryPercent',5,50,1,' %');self.spin(form,'Volume & brightness popup','hudDuration',500,6000,1,' ms')
        note=QLabel('GNOME continues to handle desktop notifications. Latto focus mode applies to Latto’s own alerts.');note.setWordWrap(True);note.setObjectName('muted');form.addRow(note);page.addStretch()

    def profiles_page(self):
        page=self.page('Profiles & backups','Keep a few favourite setups and switch between them whenever you like.')
        form=self.card(page,'Saved on this device','Loading a profile opens a draft first, so you can review it before applying.')
        self.profile_list=QListWidget();self.profile_list.setMinimumHeight(110);self.profile_list.itemDoubleClicked.connect(lambda item:self.load_selected_profile());form.addRow(self.profile_list)
        buttons=QHBoxLayout();buttons.setSpacing(8);buttons.addWidget(self.button('Save current as…',self.save_profile));buttons.addWidget(self.button('Load selected',self.load_selected_profile));form.addRow(buttons)
        buttons=QHBoxLayout();buttons.setSpacing(8);buttons.addWidget(self.button('Import profile…',self.import_profile));buttons.addWidget(self.button('Export current…',self.export_profile));form.addRow(buttons)
        self.search_entries['Save load import export profiles']=(self.pages.count()-1,self.profile_list)
        form=self.card(page,'Recovery','A configuration backup is saved before your first edit in each session. The latest ten are kept.')
        form.addRow(self.button('Review a backup…',self.review_backup));form.addRow(self.button('Open backup folder',self.open_backups));form.addRow(self.button('Reset all Studio settings…',self.reset_all))
        self.refresh_profiles();page.addStretch()

    def spin(self,form,label,key,low,high,factor=1,suffix=''):
        row=QWidget();layout=QHBoxLayout(row);layout.setContentsMargins(0,0,0,0);layout.setSpacing(12)
        slider=QSlider(Qt.Horizontal);slider.setRange(low,high);slider.setAccessibleName(label)
        widget=QSpinBox();widget.setRange(low,high);widget.setSuffix(suffix);widget.setMinimumWidth(104);widget.setAccessibleName(label+' value')
        if high>=1000:slider.setSingleStep(100);widget.setSingleStep(100)
        slider.valueChanged.connect(widget.setValue);widget.valueChanged.connect(slider.setValue);widget.valueChanged.connect(self.changed)
        layout.addWidget(slider,1);layout.addWidget(widget);self.controls[key]=(widget,factor);self.row(form,label,row)

    def choice(self,form,label,key,choices):
        widget=QComboBox()
        for text,value in choices:widget.addItem(text,value)
        widget.currentIndexChanged.connect(self.changed);self.controls[key]=widget;self.row(form,label,widget)

    def toggle(self,form,label,key):
        check=Toggle(label);check.toggled.connect(self.changed);self.controls[key]=check;form.addRow(check);self.search_entries[label]=(self.pages.count()-1,check)

    def pick_color(self,key):
        color=QColorDialog.getColor(QColor(self.colors[key].text()),self,'Choose '+key.replace('Color','').lower())
        if color.isValid():self.colors[key].setText(color.name())

    def use_preset(self,name):
        if name not in PRESETS or self.loading:return
        self.set_values(PRESETS[name]);self.changed()

    def use_layout(self,name):
        self.set_values(LAYOUTS[name]);self.changed()

    def set_values(self,data):
        before=self.loading;self.loading=True
        try:
            for key,value in data.items():
                if key in self.colors:self.colors[key].setText(value)
                elif key in self.controls:
                    widget=self.controls[key]
                    if isinstance(widget,tuple):widget[0].setValue(round(value*widget[1]))
                    elif isinstance(widget,QCheckBox):widget.setChecked(value)
                    else:widget.setCurrentIndex(max(0,widget.findData(value)))
                elif key=='compactItems' and hasattr(self,'item_checks'):
                    for item,check in self.item_checks.items():check.setChecked(item in value)
        finally:self.loading=before

    def load(self,data):
        values=validate(data);self.loading=True
        try:
            self.set_values(values);self.font.setCurrentFont(QFont(values['fontFamily']) if values['fontFamily'] else QApplication.font());self.font_system.setChecked(not values['fontFamily']);self.font.setEnabled(bool(values['fontFamily']));self.tab_list.clear()
            for key in list(values['tabs'])+[key for key in TABS if key not in values['tabs']]:
                item=QListWidgetItem(TABS[key]);item.setData(Qt.UserRole,key);item.setFlags(item.flags()|Qt.ItemIsUserCheckable|Qt.ItemIsDragEnabled);item.setCheckState(Qt.Checked if key in values['tabs'] else Qt.Unchecked);item.setSizeHint(QSize(180,38));self.tab_list.addItem(item)
            blocker=QSignalBlocker(self.codex_section)
            self.codex_section.setChecked('codex' in values['tabs'])
            del blocker
            self.pending=False;self.last_mtime=self.mtime()
        finally:self.loading=False
        self.refresh_feedback()

    def system_font_changed(self, enabled):
        self.font.setEnabled(not enabled)
        self.changed()

    def collect(self):
        data={key:edit.text() for key,edit in self.colors.items()}
        for key,widget in self.controls.items():
            if isinstance(widget,tuple):data[key]=widget[0].value() if widget[1]==1 else widget[0].value()/widget[1]
            elif isinstance(widget,QCheckBox):data[key]=widget.isChecked()
            else:data[key]=widget.currentData()
        data['fontFamily']='' if self.font_system.isChecked() else self.font.currentFont().family();data['compactItems']=[key for key,check in self.item_checks.items() if check.isChecked()];data['tabs']=[self.tab_list.item(i).data(Qt.UserRole) for i in range(self.tab_list.count()) if self.tab_list.item(i).checkState()==Qt.Checked]
        return data

    def refresh_feedback(self):
        data=self.collect();self.preview.set_data(data)
        for key,button in self.swatches.items():
            c=QColor(data[key]);button.setStyleSheet('background: '+(c.name() if c.isValid() else '#444444')+'; border: 1px solid #acb59b; border-radius: 4px;')
            self.colors[key].setProperty('invalid',not c.isValid());self.colors[key].style().unpolish(self.colors[key]);self.colors[key].style().polish(self.colors[key])
        matching='Custom / current'
        for name,values in PRESETS.items():
            matches=all(data.get(k)==v for k,v in values.items());self.preset_buttons[name].setChecked(matches)
            if matches:matching=name
        self.dimension_readout.setText(str(effective_width(data))+' px');self.finish_readout.setText(data['cornerStyle'].upper()+'\n'+data['motionStyle'].upper())
        self.preset.blockSignals(True);self.preset.setCurrentText(matching);self.preset.blockSignals(False)
        self.controls['hoverExpandDelay'][0].setEnabled(data.get('compactAlwaysVisible',False) and data.get('hoverToExpand',True))
        self.controls['topOffset'][0].setEnabled(not data.get('edgeReveal',False))
        self.controls['topOffset'][0].setToolTip('Edge activation attaches the notch directly to the top edge.' if data.get('edgeReveal',False) else '')
        actual=effective_width(data);preferred=data['idleWidth'];self.width_note.setText(f'Actual compact width: {actual} px.'+(' Extra room keeps your selected indicators and clock readable.' if actual>preferred else ' Your narrow layout is preserved.'))
        self.tab_count.setText(f'{len(data["tabs"])} of {len(TABS)} tabs visible · keep at least one enabled')
        bg=QColor(data['backgroundColor']);fg=QColor(data['textColor'])
        if bg.isValid() and fg.isValid():
            def lum(c):
                rgb=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in [c.redF(),c.greenF(),c.blueF()]]
                return sum(a*b for a,b in zip(rgb,[.2126,.7152,.0722]))
            values=sorted([lum(bg),lum(fg)]);ratio=(values[1]+.05)/(values[0]+.05)
            self.contrast.setText(f'Text contrast {ratio:.1f}:1 · '+('Easy to read' if ratio>=4.5 else 'Try a lighter text or darker background for readability'))
        self.apply_button.setEnabled(self.pending);self.apply_button.setText('Apply changes' if self.pending else 'All changes saved')

    def changed(self,*args):
        if self.loading:return
        self.pending=True;self.refresh_feedback()
        try:validate(self.collect())
        except ValueError as error:self.debounce.stop();self.message(str(error),True);return
        self.message('Unsaved preview · press Apply changes' if not self.live.isChecked() else 'Applying…')
        if self.live.isChecked():self.debounce.start()

    def live_changed(self,enabled):
        if not enabled:self.debounce.stop()
        elif self.pending:self.changed()

    def apply(self):
        self.debounce.stop()
        try:
            self.store.update(self.collect());self.pending=False;self.last_mtime=self.mtime();self.refresh_feedback();self.message('Saved to demo settings' if self.demo else 'Saved · Latto updates live')
        except (ValueError,OSError) as error:self.message(str(error),True)

    def message(self,text,error=False):
        self.status.setText(text);self.status.setStyleSheet('color: #a03f25;' if error else '')

    def move_tab(self,delta):
        row=self.tab_list.currentRow();target=row+delta
        if row<0 or not 0<=target<self.tab_list.count():return
        item=self.tab_list.takeItem(row);self.tab_list.insertItem(target,item);self.tab_list.setCurrentRow(target);self.changed()

    def reset_tabs(self):
        data=self.collect();data['tabs']=DEFAULTS['tabs'];self.load(data);self.changed()

    def reset_appearance(self):
        keys=['accentColor','backgroundColor','surfaceColor','textColor','backgroundOpacity','borderOpacity','cornerStyle','motionStyle','ambientStyle','ambientIntensity','ambientSpeed'];self.set_values({key:DEFAULTS[key] for key in keys});self.changed()

    def undo_changes(self):
        self.debounce.stop()
        try:self.load(self.store.undo_session());self.message('Session changes undone')
        except (ValueError,OSError) as error:self.message(str(error),True)

    def mtime(self):
        try:return self.store.path.stat().st_mtime_ns
        except OSError:return 0

    def external_change(self):
        if self.mtime()==self.last_mtime:return
        if self.pending:
            self.debounce.stop();self.live.setChecked(False);self.message('Settings changed elsewhere. Reload saved settings or apply your draft.',True);return
        try:self.load(self.store.read());self.message('Loaded changes made outside Studio')
        except (ValueError,OSError) as error:self.message('Could not reload: '+str(error),True)

    def reload_saved(self):
        self.debounce.stop()
        try:self.load(self.store.read());self.message('Loaded saved settings')
        except (ValueError,OSError) as error:self.message('Could not reload: '+str(error),True)

    def find_setting(self,text):
        if text not in self.search_entries:return
        index,widget=self.search_entries[text];self.nav.setCurrentRow(index);self.pages.widget(index).ensureWidgetVisible(widget,20,50);widget.setFocus();self.search.clear();self.message('Found: '+text)

    def find_first(self):
        text=self.search.text().strip().lower()
        for title in self.search_entries:
            if text and text in title.lower():self.find_setting(title);return
        if text:self.message('No matching setting. Try colour, width, clock, timer or profile.')

    def clear_search(self):self.search.clear();self.pages.setFocus()

    def refresh_profiles(self):
        self.profile_list.clear()
        for path in self.profiles.entries():
            item=QListWidgetItem(path.stem);item.setData(Qt.UserRole,str(path));self.profile_list.addItem(item)
        if not self.profile_list.count():
            item=QListWidgetItem('No saved profiles yet. Save your first look below.');item.setFlags(Qt.NoItemFlags);self.profile_list.addItem(item)

    def save_profile(self):
        name,ok=QInputDialog.getText(self,'Save a profile','Name this setup:')
        if not ok:return
        try:
            target=self.profiles.path(name)
            if target.exists() and QMessageBox.question(self,'Replace profile','Replace “'+name+'”?')!=QMessageBox.Yes:return
            self.profiles.save(name,self.collect());self.refresh_profiles();self.message('Profile saved on this device')
        except (ValueError,OSError) as error:self.message(str(error),True)

    def stage_profile(self,data,name='profile'):
        values=validate(data);self.debounce.stop();self.live.setChecked(False);self.load(values);self.pending=True;self.refresh_feedback();self.message('Reviewing '+name+' · press Apply changes to use it')

    def load_selected_profile(self):
        item=self.profile_list.currentItem()
        if item is None or not item.data(Qt.UserRole):self.message('Select a saved profile first.',True);return
        try:self.stage_profile(Profiles.read(item.data(Qt.UserRole)),item.text())
        except (ValueError,OSError) as error:self.message(str(error),True)

    def import_profile(self):
        path,_=QFileDialog.getOpenFileName(self,'Import a Latto Studio profile',str(Path.home()/'Downloads'),'JSON profiles (*.json)')
        if not path:return
        try:self.stage_profile(Profiles.read(path),Path(path).stem)
        except (ValueError,OSError) as error:self.message(str(error),True)

    def export_profile(self):
        path,_=QFileDialog.getSaveFileName(self,'Export current setup',str(Path.home()/'Downloads/latto-profile.json'),'JSON profiles (*.json)')
        if not path:return
        try:Profiles.export(path,self.collect());self.message('Profile exported · appearance and layout settings only')
        except (ValueError,OSError) as error:self.message(str(error),True)

    def review_backup(self):
        path,_=QFileDialog.getOpenFileName(self,'Review a configuration backup',str(self.store.backups),'JSON backups (*.json)')
        if not path:return
        try:
            file=Path(path)
            if file.stat().st_size>131072:raise ValueError('Backup is too large.')
            data=json.loads(file.read_text())
            if not isinstance(data,dict):raise ValueError('Choose a valid JSON configuration.')
            self.stage_profile({key:value for key,value in data.items() if key in DEFAULTS},'backup')
        except (ValueError,OSError) as error:self.message(str(error),True)

    def reset_all(self):self.stage_profile(DEFAULTS,'default Studio settings')
    def open_backups(self):
        try:self.store.backups.mkdir(parents=True,exist_ok=True);QDesktopServices.openUrl(QUrl.fromLocalFile(str(self.store.backups)))
        except OSError as error:self.message(str(error),True)

    def probe(self):
        if self.process.state()!=QProcess.NotRunning:return
        command=Path.home()/'.local/bin/latto'
        if not command.exists():self.connection.setText('○  LAUNCHER MISSING');return
        self.process.start(str(command),['status']);self.probe_timeout.start()

    def probe_finished(self,code,status):
        self.probe_timeout.stop();self.connection.setText('●  LATTO CONNECTED' if code==0 else '○  LATTO STOPPED')

    def control(self,action):
        if self.demo or self.control_process.state()!=QProcess.NotRunning:return
        self.last_action=action;self.message(action.capitalize()+'ing Latto…');self.control_process.start(str(Path.home()/'.local/bin/latto'),[action])

    def control_finished(self,code,status):
        self.message('Latto '+{'start':'started','stop':'stopped','restart':'restarted','open':'opened'}.get(self.last_action,'updated') if code==0 else 'Could not update Latto. Check its status in a terminal.',code!=0);self.probe()

    def restart(self):self.control('restart')

    def closeEvent(self,event):
        if self.pending:
            choice=QMessageBox.question(self,'Unsaved preview','Apply your pending changes before closing?',QMessageBox.Save|QMessageBox.Discard|QMessageBox.Cancel,QMessageBox.Save)
            if choice==QMessageBox.Cancel:event.ignore();return
            if choice==QMessageBox.Save:
                self.apply()
                if self.pending:event.ignore();return
        self.debounce.stop();self.probe_timeout.stop();self.process.kill()
        # Let an explicitly requested start/stop complete if Studio closes.
        if self.control_process.state()!=QProcess.NotRunning:self.control_process.waitForFinished(1500)
        event.accept()

from style import STYLE

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--config');parser.add_argument('--screenshot');parser.add_argument('--page',type=int,default=0);args=parser.parse_args()
    app=QApplication(sys.argv);app.setApplicationName('Latto Studio');app.setDesktopFileName('latto-studio');app.setStyle('Fusion');app.setStyleSheet(STYLE)
    try:window=Studio(Path(args.config) if args.config else None,monitor=not bool(args.screenshot))
    except (ValueError,OSError) as error:QMessageBox.critical(None,'Latto Studio','Could not open configuration: '+str(error));return 1
    window.nav.setCurrentRow(max(0,min(len(PAGES)-1,args.page)));window.show()
    if args.screenshot:QTimer.singleShot(300,lambda:(window.grab().save(args.screenshot),app.quit()))
    return app.exec()

if __name__=='__main__':sys.exit(main())
