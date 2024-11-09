export type EntityId = number;

export class Entity
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
