import {IDockviewPanelProps} from "dockview";
import {MenuBar, MenuItem} from "../Components/Menu.tsx";

import "./EntityHierarchyWindow.css";
import {MouseEvent, MouseEventHandler, ReactElement, useEffect, useState} from "react";

import IconVisible from "../assets/Icons/AntDesign/eye-visible.svg";
import IconInvisible from "../assets/Icons/AntDesign/eye-invisible.svg";
import {Updater, useImmer} from "use-immer";

import {EngineGlue} from "../EngineGlue";

import {enableMapSet} from "immer"
import {Entity, EntityId} from "../Entity.ts";
import * as sea from "node:sea";

enableMapSet()

type EntityMap = {
	selectedIds: Set<EntityId>;
	entities: Map<EntityId, Entity>;
	//[id: EntityId]: Entity;
};

const entityHierarchy: EntityMap = {
	selectedIds: new Set<EntityId>(),
	entities: new Map<EntityId, Entity>([
		[0, new Entity("Root", 0, [1, 2])],
		[1, new Entity("Entity 1", 1, [])],
		[2, new Entity("Entity 2", 2, [3])],
		[3, new Entity("Entity 3 in 2", 3, [])]
	])
	// // 0 is hardcoded to be the root. The editor must provide this "pseudo"-entity.
	// 0: new Entity("Root", 0, [1, 2]),
	// 1: new Entity("Entity 1", 1, []),
	// 2: new Entity("Entity 2", 2, [3]),
	// 3: new Entity("Entity 3 in 2", 3, [])
};

export default function EntityHierarchyWindow(props: IDockviewPanelProps)
{
	const [entities, updateEntities] = useImmer(entityHierarchy);
	const [filterText, setFilterText] = useState("");

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
							draft.entities.delete(entity.id);
							//delete draft[entity.id];
							draft.selectedIds.delete(entity.id);
						}
						else
						{
							draft.entities.set(entity.id, entity);
							//draft[entity.id] = entity;
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
			<EntityMenuBar searchString={filterText} onFilterTextChanged={setFilterText} />
			<EntityTree items={entities} updateItems={updateEntities} entityFilter={filterText}/>
		</>
	);
}

function EntityTreeItem({item, allEntities, updateEntities, showAsTree}: {
	item: Entity,
	allEntities: EntityMap, updateEntities: Updater<EntityMap>, showAsTree: boolean}) : ReactElement
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
				showAsTree && item.children.length > 0 &&
                <ul>
					{
						item.children.map((childId) => {
							const entity = allEntities.entities.get(childId);

							if (entity === undefined)
								return;

							return <EntityTreeItem key={entity.id} item={entity} allEntities={allEntities} updateEntities={updateEntities} showAsTree={showAsTree}/>;
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
			const entity = draft.entities.get(item.id)

			if (entity !== undefined)
			{
				entity.visible = !item.visible;
			}
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

function EntityTree({items, updateItems, entityFilter}: { items: EntityMap, updateItems: Updater<EntityMap>, entityFilter: string })
{
	const rootEntity = items.entities.get(0);

	if (entityFilter.length == 0)
	{
		return (
			<ul className="tree-view">
				{
					rootEntity && rootEntity.children.map((childId) => {
						const entity = items.entities.get(childId);

						if (entity === undefined)
							return;

						return <EntityTreeItem key={entity.id} item={entity} allEntities={items} updateEntities={updateItems} showAsTree={true} />;
					})
				}
			</ul>
		);
	}
	else
	{
		return (
			<ul className="tree-view">
				{
					Array.from(items.entities).filter(([, entity]) => {
						return entity.name.indexOf(entityFilter) != -1
					}).map(([, entity]) => {
						return <EntityTreeItem key={entity.id} item={entity} allEntities={items}
						                       updateEntities={updateItems} showAsTree={false}/>;
					})
				}
			</ul>
		);
	}
}

function EntityMenuBar({searchString, onFilterTextChanged}: {
	searchString: string,
	onFilterTextChanged: (s: string) => void
})
{
	return <MenuBar>
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
		<input className="filterEntities" placeholder="Filter entities..." content={searchString}
		       onChange={(e) => onFilterTextChanged(e.target.value)}/>
	</MenuBar>;
}
