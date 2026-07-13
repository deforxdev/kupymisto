import { motion } from 'framer-motion'
import { ArrowRight, X } from 'lucide-react'

export type ChanceEvent = { id:string; title:string; text:string; amount:number; art:'owl'|'bus'|'rich'|'fire'; deck?:'chance'|'bad'; drawnBy?:string }

type Props = { event:ChanceEvent; onContinue:()=>void }

function OwlArt(){return <svg viewBox="0 0 260 190" aria-hidden="true"><path className="rope" d="M38 22c23 35 22 101 4 145M222 22c-23 35-22 101-4 145"/><path className="owlWing" d="M86 91 44 74l29 55M174 91l42-17-29 55"/><ellipse className="owlBody" cx="130" cy="105" rx="58" ry="67"/><path className="owlHead" d="m81 67 14-46 34 28 36-28 14 47c-12 24-32 36-49 36-20 0-39-12-49-37Z"/><circle className="owlEye" cx="108" cy="66" r="17"/><circle className="owlEye" cx="152" cy="66" r="17"/><circle className="owlPupil" cx="108" cy="66" r="6"/><circle className="owlPupil" cx="152" cy="66" r="6"/><path className="owlBeak" d="m122 82 16 0-8 15Z"/><path className="bar" d="M42 153h176"/></svg>}
function BusArt(){return <svg viewBox="0 0 280 180" aria-hidden="true"><path className="road" d="M18 149h244"/><rect className="busBody" x="42" y="50" width="196" height="91" rx="18"/><path className="busTop" d="M66 31h122c20 0 34 10 42 30H48c3-18 8-30 18-30Z"/><rect className="busWindow" x="64" y="62" width="44" height="35" rx="6"/><rect className="busWindow" x="119" y="62" width="44" height="35" rx="6"/><rect className="busWindow" x="174" y="62" width="42" height="35" rx="6"/><circle className="wheel" cx="87" cy="142" r="18"/><circle className="wheel" cx="200" cy="142" r="18"/><path className="speed" d="M15 83h32M7 105h40"/></svg>}
function RichArt(){return <svg viewBox="0 0 260 180" aria-hidden="true"><path className="coat" d="M70 165c5-57 24-82 60-82s56 25 60 82Z"/><circle className="face" cx="130" cy="63" r="38"/><path className="hat" d="M78 51h104M102 48l8-38h41l9 38Z"/><path className="mustache" d="M127 69c-17-13-33 8-17 17 9 5 17-2 20-9 3 7 11 14 20 9 16-9 0-30-17-17"/><circle className="coinShape" cx="205" cy="44" r="25"/><path className="coinMark" d="M205 29v30M195 37h15c10 0 10 11 0 11h-10c-10 0-10 11 0 11h15"/></svg>}
function FireArt(){return <svg viewBox="0 0 260 180" aria-hidden="true"><path className="cotton" d="M83 144c-30 2-48-25-34-48-18-25 5-52 32-45 7-31 48-35 62-8 28-18 59 4 52 34 30 4 39 43 15 59-21 14-102 8-127 8Z"/><path className="flame" d="M132 131c-26-21-7-39 3-54 5 17 20 21 17 39 13-10 18-19 15-31 25 25 18 56-13 66-31 10-51-8-50-29 9 10 17 13 28 9Z"/></svg>}

export default function ChanceCard({event,onContinue}:Props){
  const bad=event.deck==='bad'
  return <motion.div className={`chanceBackdrop ${bad?'badBackdrop':'chanceBackdropGood'}`} initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}} transition={{duration:.25}}>
    <motion.div className="cardDrawTrail" initial={{opacity:0,scaleX:.2,rotate:-12}} animate={{opacity:[0,1,0],scaleX:[.2,1.2,1.5],rotate:-4}} transition={{duration:.9,ease:[.16,1,.3,1]}} aria-hidden="true"/>
    <motion.section
      className={`chanceCard ${event.art} ${bad?'badCard':''}`}
      initial={{opacity:0,scale:.52,rotateY:-92,rotateZ:bad?8:-8,y:130,filter:'blur(10px)'}}
      animate={{opacity:1,scale:1,rotateY:0,rotateZ:0,y:0,filter:'blur(0px)'}}
      exit={{opacity:0,scale:.76,rotateY:70,y:-100,filter:'blur(8px)'}}
      transition={{type:'spring',stiffness:260,damping:19,mass:.82}}
    >
      <motion.div className="cardShine" initial={{x:'-150%',opacity:0}} animate={{x:'170%',opacity:[0,.7,0]}} transition={{duration:.75,delay:.3,ease:'easeOut'}} aria-hidden="true"/>
      <motion.button type="button" className="chanceClose" onClick={onContinue} aria-label="Закрити" whileTap={{scale:.96,y:2}} transition={{type:'spring',stiffness:400,damping:10}}><X/></motion.button>
      <motion.span className="chanceLabel" initial={{opacity:0,y:10}} animate={{opacity:1,y:0}} transition={{delay:.28}}>{bad?'КАРТКА ХАЛЕПИ':'КАРТКА ШАНСУ'}</motion.span>
      <motion.div className="chanceArt" initial={{opacity:0,scale:.86}} animate={{opacity:1,scale:1}} transition={{delay:.18,duration:.48,ease:[.16,1,.3,1]}}>
        <img className="customCardImage" src={`/cards/${event.id}.webp`} alt="" onError={e=>{e.currentTarget.style.display='none'}}/>
        {event.art==='owl'?<OwlArt/>:event.art==='bus'?<BusArt/>:event.art==='rich'?<RichArt/>:<FireArt/>}
      </motion.div>
      <motion.h2 initial={{opacity:0,y:14}} animate={{opacity:1,y:0}} transition={{delay:.3}}>{event.title}</motion.h2>
      <motion.p initial={{opacity:0,y:12}} animate={{opacity:1,y:0}} transition={{delay:.36}}>{event.text}</motion.p>
      <motion.strong className={event.amount>=0?'positive':'negative'} initial={{opacity:0,scale:.65}} animate={{opacity:1,scale:1}} transition={{type:'spring',stiffness:400,damping:10,delay:.4}}>{event.amount>=0?'+':''}{event.amount} ₴</motion.strong>
      <motion.button type="button" className="chanceContinue" onClick={onContinue} initial={{opacity:0,y:12}} animate={{opacity:1,y:0}} transition={{type:'spring',stiffness:400,damping:10,delay:.44}} whileTap={{scale:.96,y:2}}>Продовжити<ArrowRight/></motion.button>
    </motion.section>
  </motion.div>
}
