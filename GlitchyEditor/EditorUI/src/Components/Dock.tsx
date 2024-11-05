import {
	DockviewReact,
	DockviewReadyEvent,
	IDockviewPanelProps,
} from 'dockview';
import {ChangeEvent, ReactElement, useState} from "react";
import EntityHierarchyWindow from "../Windows/EntityHierarchyWindow.tsx";
import CursorTestWindow from "../Windows/CursorTestWindow.tsx";


const components = {
	default: DefaultWindow,
	entityHierarchy: EntityHierarchyWindow,
	editPanel: CursorTestWindow
};

function DefaultWindow(props: IDockviewPanelProps<{ myValue: string }>): ReactElement
{
	const [title, setTitle] = useState<string>(props.api.title ?? '');

	const onChange = (event: ChangeEvent<HTMLInputElement>) => {
		setTitle(event.target.value);
	};

	const onClick = () => {
		props.api.setTitle(title);
	};

	return (
		<div style={{ padding: '20px', color: 'white' }}>
			<div>
				<span style={{ color: 'grey' }}>{'props.api.title='}</span>
				<span>{`${props.api.title}`}</span>
			</div>
			<input value={title} onChange={onChange} />
			<button onClick={onClick}>Change</button>
		</div>
	);
}

export default function Dock({ theme } : { theme?: string})
{
	const onReady = (event: DockviewReadyEvent) => {
		const entityHierarchyPanel = event.api.addPanel({
			id: 'entity_hierarchy_panel',
			component: 'entityHierarchy',
			title: 'Entity Hierarchy'
		});

		const editPanel = event.api.addPanel({
			id: 'edit_scene',
			component: 'editPanel',
			title: 'Edit',
			position: { referencePanel: entityHierarchyPanel, direction: "right" }
		});

		/*const playPanel =*/ event.api.addPanel({
			id: 'play_scene',
			component: 'default',
			title: 'Play',
			position: { referencePanel: editPanel }
		});

		/*const propertiesPanel =*/ event.api.addPanel({
			id: 'properties_panel',
			component: 'default',
			title: 'Properties',
			position: { referencePanel: editPanel, direction: "right" }
		});

		const logPanel = event.api.addPanel({
			id: 'log_panel',
			component: 'default',
			title: 'Log',
			position: { direction: "below" }
		});

		/*const assetBrowserPanel =*/ event.api.addPanel({
			id: 'asset_browser_panel',
			component: 'default',
			title: 'Assets',
			position: { referencePanel: logPanel }
		});
	};

	return (
		<DockviewReact
			components={components}
			onReady={onReady}
			className={`dock ${theme || 'dockview-theme-vs'}`}
		/>
	);
}

