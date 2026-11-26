#!/usr/bin/env python3
"""Exercise the real Codex QML service offscreen with a fake desktop/model helper.

No screenshots, model requests, real keystrokes, or assessment interaction occur.
All runtime/config/state/cache and IPC paths are isolated in the test directory.
"""

import argparse
import contextlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile

FAKE_BACKEND = r'''
import json, sys, time
from pathlib import Path
p=Path(__file__).resolve().parent.parent
args=sys.argv[1:];action=args[0]
with (p/'calls.jsonl').open('a') as f:f.write(json.dumps(args)+'\n')
def snap(phase='ready', answer='initial', message='Ready', busy=False):
 d=dict(phase=phase,answer=answer,message=message,error='',canCapture=True,canType=True,busy=busy)
 (p/'fake-state.json').write_text(json.dumps(d));print(json.dumps(d),flush=True)
def stored():
 try:return json.loads((p/'fake-state.json').read_text())
 except FileNotFoundError:return None
if action=='status':
 d=stored()
 if d:print(json.dumps(d),flush=True)
 else:snap()
elif action=='capture':
 req=args[args.index('--request-id')+1];prompt=args[args.index('--prompt')+1]
 if prompt=='startup':time.sleep(.35)
 snap('thinking','','Working',True)
 if prompt in ('slow','startup'):
  for i in range(150):
   if (p/'cancel').exists() and (p/'cancel').read_text()==req:
    snap('idle','','Cancelled');break
   time.sleep(.03)
  else:snap('ready','late','Finished')
 else:
  time.sleep(.2)
  snap('ready','captured','Captured')
elif action=='type':
 snap('typing','captured','Typing',True);time.sleep(.15);snap('ready','captured','Typed')
elif action=='cancel':
 req=args[args.index('--request-id')+1];(p/'cancel').write_text(req)
 d=stored();print(json.dumps(d),flush=True)
'''

QML = r'''
import QtQuick
import Quickshell
import "@@SERVICES@@" as S
ShellRoot {
 property int stage: 0
 property int ticks: 0
 property int failures: 0
 property bool released: false
 function check(name, value) { console.log("QA " + JSON.stringify({name:name,pass:value})); if(!value) failures++; }
 function data(answer, cap, typ) { return {phase:"ready",answer:answer,error:"",message:"Ready",busy:false,canCapture:cap,canType:typ,typeReason:typ?"":"Input unavailable"}; }
 Connections { target:S.IslandState; function onKeyboardFocusRequested(enabled) { if(!enabled) released=true; } }
 Timer {
  interval:30;repeat:true;running:true
  onTriggered: {
   ticks++;
   if(ticks>400) { check("watchdog",false);Qt.quit();return; }
   if(stage===0&&S.Codex.ready&&!S.Codex.busy&&!S.Codex.status.running) {
    check("status-hydration",S.Codex.answer==="initial"&&S.Codex.canCapture&&S.Codex.canType);
    check("smart-typing-mode-default",S.Codex.typingMode==="smart");
    check("capture-button-never-auto-types",!S.Codex.canCapture||S.Codex.typingMode==="smart");
    const original="    if (ok) {\n        return;\n    }";
    S.Codex.apply(data(original,true,true));check("preview-keeps-original-indentation",S.Codex.answer===original);
    S.Codex.apply(data("",true,true));check("empty-clears-old-answer",S.Codex.answer===""&&!S.Codex.canType);
    S.Codex.apply(data("answer",false,false));check("missing-services-disable-actions",!S.Codex.canCapture&&!S.Codex.canType);
    S.Codex.apply(data("answer",true,false));check("capture-available-without-typing",S.Codex.canCapture&&!S.Codex.canType);
    S.Codex.apply(data("initial",true,true));S.Codex.refresh();stage=1;
   } else if(stage===1&&!S.Codex.busy&&!S.Codex.status.running) {
    check("refresh-preserves-saved-answer",S.Codex.answer==="initial");
    released=false;S.Codex.capture("simple");S.Codex.capture("duplicate");
    check("smart-mode-fixed-during-capture",S.Codex.typingMode==="smart");stage=2;
   } else if(stage===2&&!S.Codex.busy&&S.Codex.answer==="captured") {
    check("capture-releases-keyboard-mode",released);
    check("capture-only-previews-answer",S.Codex.phase==="ready"&&S.Codex.message==="Captured"&&S.Codex.canType);
    S.Codex.capture("manual");S.Codex.capture("duplicate");stage=3;
   } else if(stage===3&&!S.Codex.busy&&S.Codex.message==="Captured") {
    check("manual-capture-ready-answer",S.Codex.phase==="ready"&&S.Codex.canType);
    released=false;S.Codex.typeAnswer();S.Codex.typeAnswer();
    check("smart-mode-used-for-explicit-type",S.Codex.typingMode==="smart");stage=4;
   } else if(stage===4&&!S.Codex.busy&&S.Codex.message==="Typed") {
    check("type-releases-keyboard-mode",released);
    check("type-returns-nonbusy",S.Codex.phase==="ready"&&S.Codex.canCapture);
    S.Codex.capture("slow");stage=5;
   } else if(stage===5&&S.Codex.worker.running&&S.Codex.phase==="thinking") {
    check("running-capture-has-request-id",S.Codex.requestId!=="");
    check("smart-mode-remains-fixed-while-worker-runs",S.Codex.typingMode==="smart");
    S.Codex.cancel();stage=6;
   } else if(stage===6&&!S.Codex.busy&&!S.Codex.status.running) {
    check("cancel-returns-nonbusy",S.Codex.message==="Cancelled"&&!S.Codex.cancelRequested);
    S.Codex.apply(data("initial",true,true));S.Codex.capture("startup");stage=7;
   } else if(stage===7&&S.Codex.worker.running&&S.Codex.phase==="capturing"&&S.Codex.requestId!=="") {
    check("startup-cancel-before-first-snapshot",S.Codex.submitting);S.Codex.cancel();stage=8;
   } else if(stage===8&&!S.Codex.busy&&!S.Codex.status.running) {
    check("startup-cancel-returns-nonbusy",S.Codex.message==="Cancelled"&&!S.Codex.cancelRequested);
    S.Codex.capture("prebegin");S.Codex.cancel();
    check("prebegin-cancel-returns-nonbusy",S.Codex.message==="Cancelled."&&!S.Codex.submitting);
    S.Codex.capture("replacement");stage=9;
   } else if(stage===9&&!S.Codex.busy&&!S.Codex.status.running) {
    check("replacement-after-cancel-completes",S.Codex.message==="Captured");
    S.Codex.refresh();stage=10;
   } else if(stage===10&&!S.Codex.busy&&!S.Codex.status.running) {
    check("final-status-remains-idle",!S.Codex.worker.running);
    console.log("QA_DONE "+JSON.stringify({failures:failures}));Qt.quit();
   }
  }
 }
}
'''

def run(directory):
    if not shutil.which("qs"):
        raise RuntimeError("Quickshell (qs) is required for this offscreen test.")
    directory.mkdir(parents=True, exist_ok=True)
    for name in ("bin", "runtime", "config", "state", "cache"):
        (directory / name).mkdir(exist_ok=True, mode=0o700)
    for name in ("calls.jsonl", "fake-state.json", "cancel"):
        (directory / name).unlink(missing_ok=True)
    (directory / "bin/latto-codex.py").write_text(FAKE_BACKEND)
    services = (Path(__file__).resolve().parents[1] / "services").as_uri()
    (directory / "shell.qml").write_text(QML.replace("@@SERVICES@@", services))
    environment = {
        **os.environ,
        "QT_QPA_PLATFORM": "offscreen",
        "XDG_RUNTIME_DIR": str(directory / "runtime"),
        "XDG_CONFIG_HOME": str(directory / "config"),
        "XDG_STATE_HOME": str(directory / "state"),
        "XDG_CACHE_HOME": str(directory / "cache"),
    }
    timed_out = False
    with (directory / "run.log").open("w") as log:
        child = subprocess.Popen(
            ["qs", "-p", str(directory / "shell.qml"), "--no-color"],
            env=environment, stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
        )
        try:
            child.wait(timeout=16)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
    log = (directory / "run.log").read_text()
    results = [json.loads(line.split("QA ", 1)[1]) for line in log.splitlines() if "QA {" in line]
    if timed_out or child.returncode != 0 or "QA_DONE" not in log:
        raise RuntimeError("Offscreen QML test did not complete:\n" + log)
    calls = [json.loads(line) for line in (directory / "calls.jsonl").read_text().splitlines()]
    captures = [call for call in calls if call[0] == "capture"]
    types = [call for call in calls if call[0] == "type"]
    cancels = [call for call in calls if call[0] == "cancel"]
    prompts = [call[call.index("--prompt") + 1] for call in captures]
    first_capture = next((index for index, call in enumerate(calls) if call[0] == "capture"), len(calls))
    def has_mode(call, mode):
        return call.count("--typing-mode") == 1 and call[call.index("--typing-mode") + 1] == mode
    results.extend([
        {"name": "duplicate-capture-blocked", "pass": prompts == ["simple", "manual", "slow", "startup", "replacement"]},
        {"name": "duplicate-type-blocked", "pass": len(types) == 1},
        {"name": "capture-never-enables-auto-typing", "pass": len(captures) == 5 and all("--auto-type" not in call for call in captures)},
        {"name": "saved-status-never-starts-input", "pass": first_capture >= 2 and all(call[0] == "status" for call in calls[:first_capture]) and calls[-1][0] == "status"},
        {"name": "missing-input-and-prebegin-cancel-never-launch", "pass": "blocked" not in prompts and "prebegin" not in prompts},
        {"name": "type-request-id", "pass": len(types) == 1 and "--request-id" in types[0]
         and bool(types[0][types[0].index("--request-id") + 1])},
        {"name": "cancel-matches-worker-request-id", "pass": len(cancels) == 2 and len(captures) == 5
         and [call[-1] for call in cancels] == [call[-1] for call in captures[2:4]]},
        {"name": "smart-reaches-capture", "pass": bool(captures) and all(has_mode(call, "smart") for call in captures)},
        {"name": "smart-reaches-explicit-type", "pass": len(types) == 1 and has_mode(types[0], "smart")},
    ])
    (directory / "results.json").write_text(json.dumps(results, indent=2))
    for result in results:
        print(("PASS " if result["pass"] else "FAIL ") + result["name"])
    passed = sum(result["pass"] for result in results)
    print(f"{passed}/{len(results)} offscreen QML checks passed")
    return 0 if passed == len(results) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, help="Keep generated test logs and fixtures in this directory")
    args = parser.parse_args()
    directory = contextlib.nullcontext(str(args.artifacts.resolve())) if args.artifacts else tempfile.TemporaryDirectory(prefix="latto-codex-ui-")
    with directory as folder:
        return run(Path(folder))


if __name__ == "__main__":
    raise SystemExit(main())
