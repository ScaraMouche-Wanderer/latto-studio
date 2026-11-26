# Passive input mode

`latto-focus passive` keeps keyboard focus with the current app while using Latto with the mouse. Opening from the notch, hovering, changing tabs, clicking buttons and dragging sliders do not request keyboard focus. Ctrl+Alt+Space still opens or closes the island.

This is a native non-focusable panel, not a browser spoofing tool. It does not patch JavaScript, read browser pages, capture another app's keyboard input, or change browser settings. The app underneath still receives keyboard input.

To type into Latto, click an editable field such as a search box, password field or Codex prompt. This explicitly enables native keyboard input and requests focus for that field. Close the island to return focus to the previous app. Keyboard input resets to off when the island closes or another app takes focus. Text entry uses normal desktop focus and can be observed by other applications.

The keyboard icon in the tab bar opens Codex. Its capture and answer processing use a background helper. Only **Type answer** starts inserting the answer into the focused editor; there is no separate keyboard switch to turn on first.

The local GNOME extension `latto-shell@voidnode` keeps Latto above application actors, including maximized and fullscreen windows raised directly by a tiling extension. It identifies the island by its title, dock type, and Quickshell executable. Stacking updates do not activate the island or resize its native surface. The integration returns focus without unmapping the island; the older X11 handoff remains a fallback when this integration is unavailable. The extension runs locally, exposes only window state and explicit focus handoff, and is enabled for future logins. Shell dialogs and the lock screen retain their normal priority.

Use `latto-focus normal` to restore the previous focus behavior; `latto-focus status` shows the current mode. Only `preserveAppFocus` in the existing Latto configuration changes, and Studio preserves this setting.

This cannot promise that a website will never infer interaction with another surface. Pages can observe mouse/pointer departure, inactivity, focus, visibility and other signals. Switching tabs, minimizing the browser, opening other apps or explicitly enabling Latto typing can still be observed by the appropriate browser APIs. Privileged extensions and screen sharing have additional visibility.

References: [document.hasFocus()](https://developer.mozilla.org/en-US/docs/Web/API/Document/hasFocus), [Page Visibility API](https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API), [PanelWindow.focusable](https://quickshell.org/docs/v0.3.2/types/Quickshell/PanelWindow/).
