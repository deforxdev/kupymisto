import { Canvas, useFrame, useThree } from '@react-three/fiber'
import { ContactShadows, RoundedBox, Text } from '@react-three/drei'
import { useEffect, useMemo, useRef } from 'react'
import { ACESFilmicToneMapping, SRGBColorSpace, type Group, type PerspectiveCamera } from 'three'
import type { BoardSize, Player } from '../api'

export type BoardCell = { name:string; kind:'corner'|'city'|'chance'|'tax'|'station'|'casino'; price?:number; color:string; description?:string }
const cityNames=['Київ','Львів','Одеса','Харків','Дніпро','Чернівці','Ужгород','Луцьк','Рівне','Житомир','Вінниця','Полтава','Черкаси','Суми','Чернігів','Тернопіль','Івано-Франківськ','Миколаїв','Херсон','Запоріжжя','Кропивницький','Біла Церква','Кременчук','Кам’янець']
const bands=['#71472f','#71472f','#55aeca','#55aeca','#cf4d83','#cf4d83','#e17132','#e17132','#c93f39','#c93f39','#e5b92f','#e5b92f','#47985c','#47985c','#3565c2','#3565c2']
export function makeCells(size:BoardSize):BoardCell[]{const side=size==='large'?15:11,total=side*4-4;let city=0;return Array.from({length:total},(_,index)=>{const lane=index%(side-1);if(lane===0){const corners=[['СТАРТ','Проходиш старт — отримуєш +200 ₴.'],['Я У ПОЛЬЩІ','Доставка через кордон: отримуєш +100 ₴.'],['БУСИФІКАЦІЯ','Міський маршрут приніс +75 ₴.'],['DON’T PUSH THE HORSES','Терпіння винагороджується: +50 ₴.']];const [name,description]=corners[index/(side-1)];return{name,description,kind:'corner',color:index===0?'#e8bd32':'#d9e2d1'}}if(index===side-3)return{name:'КАЗИНО',description:'Одна спроба: можна виграти до 150 ₴ або втратити 50 ₴.',kind:'casino',color:'#9b59b6'};if(lane===3)return{name:'ШАНС',description:'Позитивна картка з бонусом для твого балансу.',kind:'chance',color:'#ded8c7'};if(lane===7)return{name:'ХАЛЕПА',description:'Негативна картка зі штрафом для твого балансу.',kind:'tax',color:'#d8d1bf'};if(lane===5)return{name:'ВОКЗАЛ',description:'Купівля за 200 ₴. Базова оренда — 50 ₴.',kind:'city',price:200,color:'#d8d1bf'};const name=cityNames[city%cityNames.length],color=bands[Math.floor(city/2)%bands.length];city++;return{name,description:'Міська власність. Купуй і отримуй оренду.',kind:'city',price:100+(city%9)*30,color}})}
function boardPosition(index:number,side:number):[number,number,number]{const edge=side-1,half=edge/2;if(index<=edge)return[half-index,0,half];if(index<=edge*2)return[-half,0,half-(index-edge)];if(index<=edge*3)return[-half+(index-edge*2),0,-half];return[half,0,-half+(index-edge*3)]}

function Token({index,side,color,offset}:{index:number;side:number;color:string;offset:number}){
  const ref=useRef<Group>(null)
  const total=side*4-4
  const current=useRef(index)
  const target=useRef(index)
  const stepProgress=useRef(1)
  const from=useRef(boardPosition(index,side))
  const to=useRef(boardPosition(index,side))

  useEffect(()=>{target.current=index},[index])
  useFrame((_,delta)=>{
    if(!ref.current)return
    if(stepProgress.current>=1&&current.current!==target.current){
      from.current=boardPosition(current.current,side)
      current.current=(current.current+1)%total
      to.current=boardPosition(current.current,side)
      stepProgress.current=0
    }
    if(stepProgress.current<1){
      stepProgress.current=Math.min(1,stepProgress.current+delta*5.25)
      const raw=stepProgress.current
      const t=raw*raw*(3-2*raw)
      const a=from.current,b=to.current
      ref.current.position.x=a[0]+(b[0]-a[0])*t+offset
      ref.current.position.z=a[2]+(b[2]-a[2])*t+offset
      ref.current.position.y=.86+Math.sin(raw*Math.PI)*.34
      ref.current.rotation.y+=delta*4.8
    }else{
      const point=boardPosition(current.current,side)
      ref.current.position.x=point[0]+offset
      ref.current.position.z=point[2]+offset
      ref.current.position.y=.86
    }
  })
  const initial=boardPosition(index,side)
  return <group ref={ref} position={[initial[0]+offset,.86,initial[2]+offset]}>
    <mesh position={[0,.21,0]} castShadow><sphereGeometry args={[.12,24,24]}/><meshStandardMaterial color={color} roughness={.48} metalness={.04}/></mesh>
    <mesh castShadow><coneGeometry args={[.21,.42,24]}/><meshStandardMaterial color={color} roughness={.52}/></mesh>
    <mesh position={[0,-.225,0]} castShadow><cylinderGeometry args={[.235,.235,.075,24]}/><meshStandardMaterial color="#24212b" roughness={.58}/></mesh>
  </group>
}

const pipMap:Record<number,[number,number][]>={1:[[0,0]],2:[[-1,1],[1,-1]],3:[[-1,1],[0,0],[1,-1]],4:[[-1,1],[1,1],[-1,-1],[1,-1]],5:[[-1,1],[1,1],[0,0],[-1,-1],[1,-1]],6:[[-1,1],[-1,0],[-1,-1],[1,1],[1,0],[1,-1]]}
function FacePips({value,face}:{value:number;face:'top'|'front'|'back'|'left'|'right'|'bottom'}){const rotation:[number,number,number]=face==='top'?[-Math.PI/2,0,0]:face==='bottom'?[Math.PI/2,0,0]:face==='front'?[0,0,0]:face==='back'?[0,Math.PI,0]:face==='left'?[0,-Math.PI/2,0]:[0,Math.PI/2,0];const position:[number,number,number]=face==='top'?[0,.366,0]:face==='bottom'?[0,-.366,0]:face==='front'?[0,0,.366]:face==='back'?[0,0,-.366]:face==='left'?[-.366,0,0]:[.366,0,0];const pips=pipMap[value]||pipMap[1];return <group position={position} rotation={rotation}>{pips.map(([x,y],i)=><mesh key={i} position={[x*.19,y*.19,.008]}><circleGeometry args={[.055,18]}/><meshStandardMaterial color="#24232b" roughness={.5}/></mesh>)}</group>}
function Die({home,value,rolling,seed}:{home:[number,number,number];value:number;rolling:boolean;seed:number}){
  const ref=useRef<Group>(null), phase=useRef(0), wasRolling=useRef(false)
  useEffect(()=>{if(rolling&&!wasRolling.current)phase.current=0;wasRolling.current=rolling},[rolling])
  useFrame((_,delta)=>{if(!ref.current)return;if(rolling){phase.current=Math.min(1,phase.current+delta*1.35);const t=phase.current;ref.current.position.x=home[0]+Math.sin(t*Math.PI*3+seed)*.7*(1-t);ref.current.position.z=home[2]+Math.cos(t*Math.PI*2.4+seed)*.55*(1-t);ref.current.position.y=home[1]+Math.sin(t*Math.PI)*1.65+Math.abs(Math.sin(t*Math.PI*5))*.16*(1-t);ref.current.rotation.x+=delta*(15+seed*2);ref.current.rotation.y+=delta*(12+seed);ref.current.rotation.z+=delta*9}else{ref.current.position.x+=(home[0]-ref.current.position.x)*.12;ref.current.position.y+=(home[1]-ref.current.position.y)*.18;ref.current.position.z+=(home[2]-ref.current.position.z)*.12;ref.current.rotation.x+=(-ref.current.rotation.x)*.08;ref.current.rotation.z+=(-ref.current.rotation.z)*.08}})
  const faces=[value,7-value,((value+1)%6)+1,7-(((value+1)%6)+1),((value+3)%6)+1,7-(((value+3)%6)+1)]
  return <group ref={ref} position={home}><RoundedBox args={[.72,.72,.72]} radius={.115} smoothness={5} castShadow><meshStandardMaterial color="#e9e2d2" roughness={.3} metalness={.02}/></RoundedBox><FacePips value={faces[0]} face="top"/><FacePips value={faces[1]} face="bottom"/><FacePips value={faces[2]} face="front"/><FacePips value={faces[3]} face="back"/><FacePips value={faces[4]} face="left"/><FacePips value={faces[5]} face="right"/></group>
}


function ChanceDeck({drawNonce,onClick,kind}:{drawNonce:number;onClick:()=>void;kind:'chance'|'bad'}){
  const card=useRef<Group>(null)
  const previous=useRef(drawNonce)
  const progress=useRef(1)
  useEffect(()=>{if(drawNonce!==previous.current){previous.current=drawNonce;progress.current=0}},[drawNonce])
  useFrame((_,delta)=>{
    if(!card.current)return
    progress.current=Math.min(1,progress.current+delta*.82)
    const t=1-Math.pow(1-progress.current,4)
    card.current.position.x=1.55
    card.current.position.y=.69+Math.sin(t*Math.PI)*.45
    card.current.position.z=-.45
    card.current.rotation.x=-Math.PI/2+t*.45
    card.current.rotation.z=t*Math.PI*.18
    card.current.visible=progress.current<.985
  })
  return <group onClick={(e)=>{e.stopPropagation();onClick()}}>
    {Array.from({length:7}).map((_,index)=><RoundedBox key={index} args={[1.12,.055,1.48]} radius={.055} smoothness={3} position={[1.55,.50+index*.045,-.45]} castShadow><meshStandardMaterial color={kind==='chance'?(index%2?'#e8bd32':'#244f95'):(index%2?'#f0d4c6':'#b63832')} roughness={.58}/></RoundedBox>)}
    <group ref={card} position={[1.55,.69,-.45]} rotation={[-Math.PI/2,0,0]} visible={false}>
      <RoundedBox args={[1.12,.045,1.48]} radius={.055} smoothness={3} castShadow><meshStandardMaterial color={kind==='chance'?'#e8bd32':'#b63832'} roughness={.46}/></RoundedBox>
      <Text position={[0,.04,0]} rotation={[-Math.PI/2,0,0]} fontSize={.18} maxWidth={.82} color="#20202a" textAlign="center">{kind==='chance'?'ШАНС':'ХАЛЕПА'}</Text>
    </group>
  </group>
}

function BoardModel({size,positions,players,dice,rolling,onSelectCell,ownership,drawNonce,houses,onChanceDeckClick,onBadDeckClick}:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void;ownership:Record<string,string>;drawNonce:number;houses:Record<string,number>;onChanceDeckClick:()=>void;onBadDeckClick:()=>void}){
  const ownerColors=['#3167dc','#de5549','#54b87a','#efc63e','#955fc7','#e98a44'],ownerColor=(index:number)=>{const id=ownership[String(index)];const playerIndex=players.findIndex(player=>player.id===id);return playerIndex>=0?ownerColors[playerIndex%ownerColors.length]:null},group=useRef<Group>(null),drag=useRef({active:false,x:0,y:0,targetX:-.04,targetY:0}),zoom=useRef(size==='large'?18.5:16.2),{gl,camera}=useThree(),cells=useMemo(()=>makeCells(size),[size]),side=size==='large'?15:11,edge=side-1,boardWidth=edge+1.7,playerColors=['#3167dc','#de5549','#54b87a','#efc63e','#955fc7','#e98a44']
  useEffect(()=>{const canvas=gl.domElement,context=(e:MouseEvent)=>e.preventDefault(),down=(e:PointerEvent)=>{if(e.button!==2)return;e.preventDefault();drag.current.active=true;drag.current.x=e.clientX;drag.current.y=e.clientY;canvas.setPointerCapture?.(e.pointerId);canvas.classList.add('isRotating')},move=(e:PointerEvent)=>{if(!drag.current.active||(e.buttons&2)!==2)return;const dx=e.clientX-drag.current.x,dy=e.clientY-drag.current.y;drag.current.x=e.clientX;drag.current.y=e.clientY;drag.current.targetY+=dx*.008;drag.current.targetX=Math.max(-.38,Math.min(.32,drag.current.targetX+dy*.005))},up=(e:PointerEvent)=>{if(e.button!==2)return;drag.current.active=false;canvas.releasePointerCapture?.(e.pointerId);canvas.classList.remove('isRotating')},wheel=(e:WheelEvent)=>{e.preventDefault();zoom.current=Math.max(size==='large'?13.5:11.5,Math.min(size==='large'?25:22,zoom.current+e.deltaY*.012))};canvas.addEventListener('contextmenu',context);canvas.addEventListener('pointerdown',down);canvas.addEventListener('pointermove',move);canvas.addEventListener('pointerup',up);canvas.addEventListener('pointercancel',up);canvas.addEventListener('wheel',wheel,{passive:false});return()=>{canvas.removeEventListener('contextmenu',context);canvas.removeEventListener('pointerdown',down);canvas.removeEventListener('pointermove',move);canvas.removeEventListener('pointerup',up);canvas.removeEventListener('pointercancel',up);canvas.removeEventListener('wheel',wheel)}},[gl,size])
  useFrame(()=>{if(group.current){group.current.rotation.y+=(drag.current.targetY-group.current.rotation.y)*.12;group.current.rotation.x+=(drag.current.targetX-group.current.rotation.x)*.12}const cam=camera as PerspectiveCamera;const length=Math.hypot(cam.position.x,cam.position.y,cam.position.z);const target=zoom.current;if(Math.abs(length-target)>.01)cam.position.multiplyScalar((length+(target-length)*.12)/length)})
  return <group ref={group}><RoundedBox args={[boardWidth,.42,boardWidth]} radius={.18} smoothness={4} receiveShadow><meshStandardMaterial color="#22212b" roughness={.65}/></RoundedBox><RoundedBox args={[boardWidth-.28,.20,boardWidth-.28]} radius={.12} smoothness={4} position={[0,.28,0]} receiveShadow><meshStandardMaterial color="#78a881" roughness={.82} metalness={0}/></RoundedBox>{cells.map((cell,index)=>{const[x,,z]=boardPosition(index,side),corner=cell.kind==='corner',rotation=index<=edge?0:index<=edge*2?-Math.PI/2:index<=edge*3?Math.PI:Math.PI/2;return <group key={index} position={[x,.43,z]} rotation={[0,rotation,0]} onClick={(event)=>{event.stopPropagation();onSelectCell(index)}} onPointerOver={(event)=>{event.stopPropagation();gl.domElement.style.cursor='pointer'}} onPointerOut={()=>{gl.domElement.style.cursor=drag.current.active?'grabbing':'default'}}><RoundedBox args={[corner?1.05:.78,.12,1.05]} radius={.035} smoothness={2} receiveShadow><meshStandardMaterial color={corner?cell.color:'#cfc6af'} roughness={.86} metalness={0}/></RoundedBox>{!corner&&<mesh position={[0,.085,-.38]}><boxGeometry args={[.76,.045,.26]}/><meshStandardMaterial color={cell.color}/></mesh>}<Text position={[0,.112,.02]} rotation={[-Math.PI/2,0,0]} fontSize={corner?.12:.09} maxWidth={.68} color="#20202a" textAlign="center" anchorX="center" anchorY="middle">{cell.name}</Text>{ownerColor(index)&&<group position={[0,.19,0]}>
          <mesh position={[0,0,-.54]}><boxGeometry args={[corner?1.1:.84,.055,.035]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>
          <mesh position={[0,0,.54]}><boxGeometry args={[corner?1.1:.84,.055,.035]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>
          <mesh position={[-(corner?0.55:0.42),0,0]}><boxGeometry args={[.035,.055,1.08]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>
          <mesh position={[(corner?0.55:0.42),0,0]}><boxGeometry args={[.035,.055,1.08]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>
          {Array.from({length:houses[String(index)]||0}).map((_,h)=><mesh key={h} position={[-.22+h*.22,.17,-.08]} castShadow><boxGeometry args={[.16,.22,.16]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>)}
        </group>}{cell.price&&<Text position={[0,.113,.29]} rotation={[-Math.PI/2,0,0]} fontSize={.07} color="#20202a" anchorX="center" anchorY="middle">{cell.price} ₴</Text>}</group>})}{players.map((player,index)=><Token key={player.id} index={positions[index]||0} side={side} color={playerColors[index%playerColors.length]} offset={(index%3-.8)*.16}/>)}<ChanceDeck drawNonce={drawNonce} onClick={onChanceDeckClick} kind="chance"/><group position={[-1.55,.02,-.45]}><ChanceDeck drawNonce={drawNonce} onClick={onBadDeckClick} kind="bad"/></group><Die home={[-.5,.86,.45]} value={dice[0]} rolling={rolling} seed={1}/><Die home={[.5,.86,.45]} value={dice[1]} rolling={rolling} seed={2}/></group>
}
export default function ClassicBoard3D(props:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void;ownership:Record<string,string>;drawNonce:number;houses:Record<string,number>;onChanceDeckClick:()=>void;onBadDeckClick:()=>void}){const camera=props.size==='large'?[0,12.5,13.8]as[number,number,number]:[0,10.8,12.5]as[number,number,number];return <Canvas dpr={[1,1.6]} shadows camera={{position:camera,fov:38}} gl={{antialias:true,toneMapping:ACESFilmicToneMapping,toneMappingExposure:.72,outputColorSpace:SRGBColorSpace}}><color attach="background" args={['#557b61']}/><ambientLight intensity={.42}/><hemisphereLight args={['#c3d9c5','#263b2d',.72]}/><directionalLight position={[7,12,5]} intensity={1.55} castShadow shadow-mapSize={[1024,1024]}/><BoardModel {...props}/><ContactShadows position={[0,-.24,0]} opacity={.3} scale={20} blur={2.4} far={8}/></Canvas>}
