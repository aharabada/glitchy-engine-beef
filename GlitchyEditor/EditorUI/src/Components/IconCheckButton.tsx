import {MouseEventHandler, ReactElement} from "react";

export function IconCheckButton({isChecked, iconChecked, iconUnchecked, onClick} : {isChecked: boolean, iconChecked: string, iconUnchecked: string, onClick: MouseEventHandler }) : ReactElement
{
	return (
		<div onClick={onClick}>
			<img src={isChecked ? iconChecked : iconUnchecked} alt="" />
		</div>
	);
}
