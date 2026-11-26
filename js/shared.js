// Shared skill lists for the player questionnaire (q.html). Keep in step with index.html.
const SQUADS=["Juniors","Seniors","Ladies"];
const AGE_GROUPS=["U9","U10","U11","U12","U13","U14","U15","U16","U17","U18","U19","Adult"];
const SKILLS=[
 {key:"bat",name:"Batting",items:[["bat_grip","Grip, stance and set-up"],["bat_ff","Front-foot drives"],["bat_bf","Back-foot play (pull, cut)"],["bat_pace","Playing pace"],["bat_off","Playing the off side"],["bat_leg","Playing the leg side"],["bat_spin","Playing spin"],["bat_run","Running between the wickets"],["bat_rot","Rotating the strike"],["bat_power","Boundary and power hitting"]]},
 {key:"shots",name:"Batting shots",detailOnly:true,items:[["sh_fd","Forward defensive"],["sh_cover","Cover drive"],["sh_square","Square drive"],["sh_on","On drive"],["sh_cut","Cut"],["sh_late","Late cut"],["sh_pull","Pull"],["sh_hook","Hook"],["sh_glance","Leg glance"],["sh_sweep","Sweep"],["sh_lap","Lap sweep"],["sh_slog","Slog sweep"],["sh_scoop","Scoop"],["sh_ramp","Ramp"]]},
 {key:"bowl",name:"Bowling",items:[["bowl_acc","Line and length accuracy"],["bowl_seampos","Seam position"],["bowl_pace","Pace or spin and drift"],["bowl_var","Variations"],["bowl_new","New ball, swing and seam"],["bowl_death","Bowling at the death"],["bowl_spell","Consistency over a spell"]]},
 {key:"field",name:"Fielding",items:[["fld_close","Close catching"],["fld_slip","Slip catching"],["fld_high","High catches"],["fld_ground","Ground fielding and pick-up"],["fld_throw","Throwing accuracy"],["fld_dist","Throwing distance"],["fld_antic","Anticipation and backing up"]]},
 {key:"wk",name:"Wicket-keeping",items:[["wk_back","Standing back to pace"],["wk_up","Standing up to spin"],["wk_feet","Footwork and movement"],["wk_upseam","Standing up to seam bowlers"],["wk_catchup","Catching when stood up"],["wk_stump","Stumpings"],["wk_runout","Run-outs"]]},
 {key:"fit",name:"Fitness",items:[["fit_speed","Speed (sprinting between wickets)"],["fit_agility","Agility and change of direction"],["fit_endur","Endurance across a full innings or day"],["fit_strength","Strength"],["fit_power","Power (jumping, throwing, hitting)"],["fit_mobility","Flexibility and mobility"],["fit_core","Core stability and balance"]]},
 {key:"tac",name:"Tactical knowledge",items:[["tac_read","Reading the match situation"],["tac_inn","Building an innings"],["tac_field","Field placings"],["tac_plans","Bowling plans to batters"],["tac_laws","Laws and playing conditions"],["tac_comm","On-field communication"]]}
];
const DELIVERIES={
 seam:{name:"Seam deliveries",items:[["dl_se_stock","Stock ball"],["dl_se_away","Away swinger"],["dl_se_in","Inswinger"],["dl_se_yorker","Yorker"],["dl_se_bouncer","Bouncer"],["dl_se_slower","Slower ball"]]},
 off:{name:"Off-spin deliveries",items:[["dl_os_stock","Stock ball"],["dl_os_top","Top spinner"],["dl_os_arm","Arm ball"],["dl_os_carrom","Carrom ball"],["dl_os_quick","Quicker ball"]]},
 leg:{name:"Leg-spin deliveries",items:[["dl_ls_stock","Stock ball"],["dl_ls_top","Top spinner"],["dl_ls_flipper","Flipper"],["dl_ls_googly","Googly"],["dl_ls_slider","Slider"],["dl_ls_quick","Quicker ball"]]}
};
const BOWL_TYPES=["Seam (fast)","Seam (fast-medium)","Seam (medium)","Off-spin","Left-arm orthodox (finger spin)","Leg-spin","Left-arm wrist spin"];
const isKeeper=p=>p.profile.keeper==="Yes"||p.profile.role==="Wicket-keeper batter";
function bowlArea(p,a){const f=bowlFamily(p);const lab={bowl_pace:f==="seam"?"Swing":f?"Drift":"Swing or drift"};if(f==="seam")lab.bowl_new="New ball and seam movement";return Object.assign({},a,{items:a.items.map(([k,l])=>[k,lab[k]||l])})}
const areasFor=(p,overview)=>{const L=SKILLS.filter(a=>(a.key!=="wk"||isKeeper(p))&&(a.key!=="bowl"||p.profile.bowlArm!=="Doesn't bowl")&&(!overview||!a.detailOnly)).map(a=>a.key==="bowl"?bowlArea(p,a):a);const d=!overview&&deliveryArea(p);if(d)L.splice(L.findIndex(a=>a.key==="bowl")+1,0,d);return L};
function bowlFamily(p){const t=p.profile.bowlType||"";if(p.profile.bowlArm==="Doesn't bowl"||!t)return null;if(t.startsWith("Seam"))return"seam";if(t==="Off-spin"||t.startsWith("Left-arm orthodox"))return"off";if(t==="Leg-spin"||t==="Left-arm wrist spin")return"leg";return null}
function deliveryArea(p){const f=bowlFamily(p);return f?Object.assign({key:"deliv",detailOnly:true},DELIVERIES[f]):null}
const isJunior=p=>p.ageGroup&&p.ageGroup!=="Adult";
