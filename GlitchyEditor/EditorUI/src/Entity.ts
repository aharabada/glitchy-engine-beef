export type EntityId = string;

export class Entity
{
	name: string;
	id: EntityId;
	visible: boolean = true;
	children: EntityId[];

	constructor(name: string, id: EntityId, children: EntityId[] = [])
	{
		this.name = name;
		this.id = id;
		this.children = children;
	}
}
