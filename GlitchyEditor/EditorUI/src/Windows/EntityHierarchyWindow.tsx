import {IDockviewPanelProps} from "dockview";
import {MenuBar, MenuItem} from "../Components/Menu.tsx";

import "./EntityHierarchyWindow.css";
import {MouseEvent, MouseEventHandler, ReactElement, useEffect} from "react";

import IconVisible from "../assets/Icons/AntDesign/eye-visible.svg";
import IconInvisible from "../assets/Icons/AntDesign/eye-invisible.svg";
import {Updater, useImmer} from "use-immer";

import {EngineGlue} from "../EngineGlue";

import {enableMapSet} from "immer"
import {Entity, EntityId} from "../Entity.ts";

enableMapSet()

type EntityMap = {
	selectedIds: Set<EntityId>;
	[id: EntityId]: Entity;
};

const entityHierarchy: EntityMap = {
	selectedIds: new Set<EntityId>(),
	// 0 is hardcoded to be the root. The editor must provide this "pseudo"-entity.
	0: new Entity("Root", 0, [])
};

export default function EntityHierarchyWindow(props: IDockviewPanelProps)
{
	const [entities, updateEntities] = useImmer(entityHierarchy);

	useEffect(() => {
		EngineGlue.onUpdateEntities = (entities: Entity[]) => {
			updateEntities(draft => {
				try
				{
					for (const entity of entities)
					{
						// console.log(`${entity.id}: "${entity.name ?? "deleted"}",
						// ${entity.visible ? "Visible" : "Invisible"}, ${entity.children.length} Children: [${entity.children}]`)

						if (entity.name === "undefined")
						{
							delete draft[entity.id];
							draft.selectedIds.delete(entity.id);
						}
						else
						{
							draft[entity.id] = entity;
						}
					}
				}
				catch (e)
				{
					console.log(`Failed to update entities: ${e}`);
				}
			});
		};

		EngineGlue.requestEntityHierarchyUpdate();

		return () => {
			delete EngineGlue.onUpdateEntities;
		};
	}, [updateEntities]);

	return (
		<>
			<MenuBar>
				<MenuItem text="Create">
					<MenuItem text="Empty Entity" onClick={window.EngineGlue.onClickCreateEmptyEntity}/>
					<MenuItem text="Parent Entity">
						<MenuItem text="Test 1 (lang)">
							<MenuItem text="Du">
								<MenuItem text="Übertreibst">
									<MenuItem text="Völlig"/>
									<MenuItem text="Du Hund!"/>
								</MenuItem>
							</MenuItem>
						</MenuItem>
						<MenuItem text="Test 2">
							<MenuItem text="Ach komm,"/>
						</MenuItem>
						<MenuItem text="Test 3">
							<MenuItem text="Hör auf!"/>
						</MenuItem>
					</MenuItem>
					<MenuItem text="Child Entity"/>
				</MenuItem>
				<MenuItem text="Delete">
					<MenuItem text="Selected"/>
					<MenuItem text="All"/>
				</MenuItem>
				<MenuItem text="Copy">
				</MenuItem>
				<input className="filterEntities" placeholder="Filter entities..."/>
			</MenuBar>
			<EntityTree items={entities} updateItems={updateEntities}/>
		</>
	);
}

function EntityTreeItem({item, allEntities, updateEntities}: {
	item: Entity,
	allEntities: EntityMap, updateEntities: Updater<EntityMap>}) : ReactElement
{
	//const [isOpen, setOpen] = useState(false);

	const isSelected = allEntities.selectedIds.has(item.id);
	//const isVisible = allEntities[item.id].visible;

	function handleClick(event: MouseEvent)
	{
		console.log("Clicked" + item.name);
		updateEntities(draft => {
			if (isSelected)
			{
				draft.selectedIds.delete(item.id);
			}
			else
			{
				draft.selectedIds.add(item.id);
			}
		});

		event.stopPropagation();
	}

	function toggleVisibility(event: MouseEvent)
	{
		event.stopPropagation();

		// updateEntities(draft => {
		// 	draft[item.id].visible = !draft[item.id].visible;
		// });

		//event.stopPropagation();
	}

	return (
		<li>
			<div className={"tree-view__item " + (isSelected ? "selected" : "")} onClick={handleClick}>
				<div className="tree-view__item__text">
					{item.name}
				</div>
				<VisibilityToggle item={item} onClick={toggleVisibility} updateEntities={updateEntities} />
			</div>

			{
				item.children.length > 0 &&
                <ul>
					{
						item.children.map((childId) => {
							const entity: Entity = allEntities[childId];

							if (entity === undefined)
								return;

							return <EntityTreeItem key={entity.id} item={entity} allEntities={allEntities} updateEntities={updateEntities}/>;
						})
					}
                </ul>
			}
		</li>
	);
}

function VisibilityToggle({item, onClick, updateEntities} : {item: Entity, onClick: MouseEventHandler, updateEntities: Updater<EntityMap>}) {
	function clickHandler(event: MouseEvent)
	{
		updateEntities(draft => {
			draft[item.id].visible = !item.visible;
		});

		console.log("Clickidy" + item.visible);
		
		onClick(event);

		event.stopPropagation();
	}

	return (
		<div onClick={clickHandler}>
			<img src={item.visible ? IconVisible : IconInvisible} />
		</div>
	);
}

function EntityTree({items, updateItems}: { items: EntityMap, updateItems: Updater<EntityMap> })
{
	return (
		<ul className="tree-view">
			{
				items[0].children.map((childId) => {
					const entity: Entity = items[childId];

					if (entity === undefined)
						return;

					return <EntityTreeItem key={entity.id} item={entity} allEntities={items} updateEntities={updateItems} />;
				})
			}
		</ul>
	);
}
