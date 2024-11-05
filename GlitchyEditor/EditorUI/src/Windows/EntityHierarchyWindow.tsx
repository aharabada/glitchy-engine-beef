import {IDockviewPanelProps} from "dockview";
import {MenuBar, MenuItem} from "../Components/Menu.tsx";

import "./EntityHierarchyWindow.css";
import {MouseEventHandler, ReactElement, MouseEvent} from "react";

import IconVisible from "../assets/Icons/AntDesign/eye-visible.svg";
import IconInvisible from "../assets/Icons/AntDesign/eye-invisible.svg";
import {Updater, useImmer} from "use-immer";

import {EngineGlue} from "../EngineGlue";

type EntityId = number;

class Entity
{
	name: string;
	id: EntityId;
	visible: boolean = true;
	children: EntityId[];

	constructor(name: string, key: number, children: EntityId[] = [])
	{
		this.name = name;
		this.id = key;
		this.children = children;
	}
}

type EntityMap = {
	selectedIds: EntityId[];
	[id: EntityId]: Entity;
};

const entityHierarchy: EntityMap = {
	selectedIds: [],

	0: new Entity("Entity Root", 0, [1, 4]),
	1: new Entity("Entity Entity 1", 1, [2, 3]),
	2: new Entity("Entity Entity 1.1", 2),
	3: new Entity("Entity Entity 1.2", 3),
	4: new Entity("Entity Entity 2", 4, [5, 6]),
	5: new Entity("Entity Entity 2.1", 5),
	6: new Entity("Entity Entity 2.2", 6, [7]),
	7: new Entity("Entity Entity 2.2.1", 7, [8, 9]),
	8: new Entity("Entity Entity 2.2.1.1", 8),
	9: new Entity("Entity Entity 2.2.1.2", 9)
};

export default function EntityHierarchyWindow(props: IDockviewPanelProps)
{
	const [entities, updateEntities] = useImmer(entityHierarchy);

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
			<button className="title-bar__button close" onClick={EngineGlue.handleClickCloseWindow}>🗙</button>
		</>
	);
}

function EntityTreeItem({item, allEntities, updateEntities}: {
	item: Entity,
	allEntities: EntityMap, updateEntities: Updater<EntityMap>}) : ReactElement
{
	//const [isOpen, setOpen] = useState(false);

	const isSelected = allEntities.selectedIds.includes(item.id);
	//const isVisible = allEntities[item.id].visible;

	function handleClick(event: MouseEvent)
	{
		console.log("Clicked" + item.name);
		updateEntities(draft => {
			if (isSelected)
			{
				draft.selectedIds = allEntities.selectedIds.filter((id) => {return id != item.id});
			}
			else
			{
				draft.selectedIds.push(item.id);
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

				return <EntityTreeItem key={entity.id} item={entity} allEntities={items} updateEntities={updateItems} />;
				})
			}
		</ul>
	);
}
