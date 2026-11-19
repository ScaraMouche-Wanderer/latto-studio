"""Studio chrome: warm paper, ink text and a copper accent."""
STYLE='''
QWidget { background: #f5f3ed; color: #292e29; font-family: "Noto Sans"; font-size: 12px; }
QLabel { background: transparent; }
QFrame#sidebar { background: #eae8df; border-right: 1px solid #d0d2c4; }
QLabel#brand { font-size: 38px; font-weight: 700; letter-spacing: -2px; }
QLabel#wordmarkNote { font-family: "JetBrains Mono"; color: #686e60; font-size: 10px; letter-spacing: 4px; }
QLabel#title { font-size: 28px; font-weight: 600; letter-spacing: -1px; }
QLabel#section { font-size: 18px; font-weight: 500; letter-spacing: -0.3px; }
QLabel#cardTitle { font-size: 13px; font-weight: 600; color: #2e342a; }
QLabel#muted { color: #636b5d; font-size: 11px; }
QLabel#sideNote { color: #686f60; font-size: 10px; }
QLabel#eyebrow { font-family: "JetBrains Mono"; color: #626959; font-size: 9px; letter-spacing: 1px; }
QLabel#pageIndex { font-family: "JetBrains Mono"; color: #914c29; font-size: 10px; letter-spacing: 2px; }
QLabel#badge { color: #55644c; border-top: 1px solid #cbd0bf; padding-top: 14px; font-family: "JetBrains Mono"; font-size: 9px; }
QFrame#card { background: #fffdf8; border: 1px solid #d3d5c7; border-radius: 6px; }
QFrame#card QWidget, QFrame#previewCard QWidget { background: transparent; }
QFrame#previewCard { background: #efeee6; border: 1px solid #d3d5c7; border-radius: 8px; }
QFrame#footer { border-top: 1px solid #cfd3c2; }
QLabel#status { color: #5f6856; font-size: 11px; }
QLabel#specValue { font-family: "JetBrains Mono"; font-size: 20px; color: #292e29; }
QLabel#previewNote { color: #646e5b; font-size: 11px; }
QLabel#specSummary { color: #606954; font-family: "JetBrains Mono"; font-size: 10px; }
QLineEdit, QSpinBox, QComboBox { background: #fffef9; border: 1px solid #bdc4b0; border-radius: 4px; padding: 7px 9px; min-height: 18px; selection-background-color: #edd4bd; }
QLineEdit { placeholder-text-color: #747d68; selection-color: #33271d; }
QLineEdit#search { background: #fffef9; color: #3e4736; }
QLineEdit:focus, QSpinBox:focus, QComboBox:focus { border-color: #a35e33; }
QLineEdit[invalid="true"] { border-color: #ae472b; }
QComboBox::drop-down { border: none; width: 22px; }
QComboBox QAbstractItemView { background: #fffef8; color: #292e29; selection-background-color: #eadcc7; border: 1px solid #bbc3ae; padding: 4px; }
QSpinBox::up-button, QSpinBox::down-button { width: 15px; border: none; }
QPushButton { background: #eeeee3; border: 1px solid #c3c9b6; border-radius: 4px; padding: 8px 12px; min-height: 16px; }
QPushButton:hover { background: #e4e7d9; border-color: #a58a68; }
QPushButton:pressed { background: #daddcf; }
QPushButton:focus { border-color: #a35e33; }
QPushButton:disabled { color: #747c6a; background: #e6e8dc; border-color: #cfd5c3; }
QPushButton#paletteTile { min-height: 88px; max-height: 88px; padding: 0; }
QPushButton#apply { background: #995b35; color: #fffaf4; border-color: #995b35; font-weight: 600; }
QPushButton#apply:hover { background: #854b29; }
QPushButton#apply:disabled { background: #e7e5d8; color: #686d5a; border-color: #c7cab7; }
QPushButton#segment { border: 1px solid transparent; background: transparent; color: #66715b; padding: 5px 8px; font-size: 10px; }
QPushButton#segment:checked { background: #e1e5d6; border-color: #a8b396; color: #2e3b24; }
QPushButton#stageChip { font-size: 10px; padding: 4px 9px; min-height: 14px; background: #f8f8ef; }
QPushButton#stageChip:checked { border-color: #a35e33; color: #814724; }
QListWidget { background: #fffef8; border: 1px solid #c4ccb7; border-radius: 4px; padding: 5px; outline: none; }
QListWidget#navigation { background: transparent; border: none; padding: 0; }
QListWidget::item { border-radius: 4px; padding: 6px 10px; }
QListWidget::item:selected { background: #e8dbc5; color: #3c3022; }
QListWidget::item:hover { background: #eceee1; }
QListWidget::indicator { width: 17px; height: 17px; border: 1px solid #909f7c; border-radius: 3px; background: #fffdf7; margin-right: 7px; }
QListWidget::indicator:checked { background: #a9653b; border: 2px solid #dfb28e; }
QScrollArea { border: none; background: transparent; }
QScrollBar:vertical { background: transparent; width: 6px; border: none; margin: 0; }
QScrollBar::handle:vertical { background: #b1bca2; border-radius: 3px; min-height: 30px; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical { background: none; }
QCheckBox { spacing: 10px; padding: 2px; }
QSlider::groove:horizontal { background: #cbd2bf; height: 3px; border-radius: 1px; }
QSlider::sub-page:horizontal { background: #a66942; border-radius: 1px; }
QSlider::handle:horizontal { background: #fffaf3; border: 2px solid #a16a41; width: 12px; height: 12px; margin: -6px 0; border-radius: 7px; }
QToolTip { background: #fffcef; color: #343d2c; border: 1px solid #b1b596; padding: 7px; }
'''
