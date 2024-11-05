import {ReactElement} from "react";

import "./StartupCard.css"

export function StartupCard(): ReactElement
{
	return (
		<div className="backdrop">
			<div className="card">
				<div className="content">
					<h1>Glitchy Engine</h1>
					<h2>Projects:</h2>
					<button>Create New</button>
					<h3>Recent projects:</h3>
					<ul>
						<li>Bli</li>
						<li>Bla</li>
						<li>Blub</li>
					</ul>
				</div>
			</div>
		</div>
	);
}
