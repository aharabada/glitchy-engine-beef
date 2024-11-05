import {IDockviewPanelProps} from "dockview";

import "./CursorTestWindow.css"

export default function CursorTestWindow(props: IDockviewPanelProps)
{
	return (
		<>
			<h1>CSS Cursors</h1>

			<div className="cursors">
				<div className="auto">auto</div>
				<div className="default">default</div>
				<div className="none">none</div>
				<div className="context-menu">context-menu</div>
				<div className="help">help</div>
				<div className="pointer">pointer</div>
				<div className="progress">progress</div>
				<div className="wait">wait</div>
				<div className="cell">cell</div>
				<div className="crosshair">crosshair</div>
				<div className="text">text</div>
				<div className="vertical-text">vertical-text</div>
				<div className="alias">alias</div>
				<div className="copy">copy</div>
				<div className="move">move</div>
				<div className="no-drop">no-drop</div>
				<div className="not-allowed">not-allowed</div>
				<div className="all-scroll">all-scroll</div>
				<div className="col-resize">col-resize</div>
				<div className="row-resize">row-resize</div>
				<div className="n-resize">n-resize</div>
				<div className="s-resize">s-resize</div>
				<div className="e-resize">e-resize</div>
				<div className="w-resize">w-resize</div>
				<div className="ns-resize">ns-resize</div>
				<div className="ew-resize">ew-resize</div>
				<div className="ne-resize">ne-resize</div>
				<div className="nw-resize">nw-resize</div>
				<div className="se-resize">se-resize</div>
				<div className="sw-resize">sw-resize</div>
				<div className="nesw-resize">nesw-resize</div>
				<div className="nwse-resize">nwse-resize</div>
				<div className="zoom-in">zoom-in</div>
				<div className="zoom-out">zoom-out</div>
				<div className="custom">custom</div>
			</div>
		</>
	);
}