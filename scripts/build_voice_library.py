"""Author and render a reusable, explicitly authored local speech library."""
import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'helper'))
from speech_engine import SpeechEngine
VOICES={'crier':'bm_george','fisherman':'bm_daniel','barkeep':'am_michael','baker':'bf_emma','elowen':'bf_isabella','resident_living':'af_heart','banker':'bm_fable','joiner':'bm_fable','shipwright':'bf_emma','curator':'bm_george','innkeeper':'bf_isabella','healer':'af_heart'}
LINES={
'welcome':('crier',['Hear ye, good people of Vesper! Welcome to the city of bridges. Keep the quays clear, and lend an ear to your neighbours.','Good day, travellers. The Mint stands beside this square. Ask for news if you wish to know what is happening in town.']),
'bank':('crier',['The Mint keeps your valuables safe. Speak to the banker, or simply say bank when you are nearby.','Travellers, the Mint serves both sides of its doorway. You need not crowd the counter to reach your bank box.']),
'flavor':('crier',['Vesper is a city of traders, canals, and stone bridges. From the docks to the museum, every crossing has a story.','For a quiet hour, visit the museum. For a warm welcome, seek the Ironwood Inn.']),
'shortage':('crier',['News from the Marsh Hall! Garrick needs fresh fish for his kitchen. A patient angler can earn an honest supper.','The Marsh Hall kitchen is short of fish. Anglers and helpful travellers, Garrick could use your catch.']),
'fish_news':('crier',['Fresh fish have reached the Marsh Hall! Corin has delivered his catch to Garrick. The kitchen is supplied again.','Good news from the waterfront. Corin has kept his promise, and his fish have reached the tavern kitchen.']),
'bread_news':('crier',['Bread from the Twisted Oven has arrived at the Marsh Hall. Elowen has delivered Lysa\'s basket safely.','A delivery well done! The tavern now has fresh bread, carried over the bridges by Elowen.']),
'player_news':('crier',['A traveller has helped supply the Marsh Hall. Garrick sends his thanks for the fresh fish.','News worth sharing: a visitor has brought fish to the tavern kitchen. Vesper remembers a helping hand.']),
'museum_news':('crier',['The museum\'s astrolabe has arrived! A traveller has completed Elowen\'s delivery and returned a piece of history to Vesper.']),
'bread_open':('crier',['The Twisted Oven sells warm bread for two gold a loaf. Ask Lysa when you reach her shop.']),
'courier_request':('crier',['Elowen, could you take a basket from Lysa to the Marsh Hall? The kitchen is short of bread.']),
'courier_accept':('elowen',['I can help. I will collect the bread from Lysa, then carry it to Garrick.','Yes, I have room for a basket. I will go to the Twisted Oven first.']),
'bread_pickup':('elowen',['Lysa, I promised to take bread to the Marsh Hall. Is the basket ready?','I am here for Garrick\'s bread, Lysa. The bridges should be quiet enough now.']),
'bread_handover':('baker',['Here you are, Elowen. Four fresh loaves, wrapped for the walk. Thank you for carrying them.','The basket is ready. Mind the cloth; those loaves are still warm.']),
'bread_arrival':('elowen',['Garrick, I brought Lysa\'s bread. All four loaves, and not a crumb lost on the bridges.','A basket from the Twisted Oven. Lysa sends her regards, along with your bread.']),
'bread_thanks':('barkeep',['Thank you, Elowen. That is one promise kept and four good loaves in the kitchen.','Set the basket here. Lysa\'s bread always brings people back to the table.']),
'fish_offer':('fisherman',['Garrick, the catch is landed. I can bring three fresh fish to your kitchen.','Three good fish in the basket. Shall I leave them with you, Garrick?']),
'fish_thanks':('barkeep',['Well caught, Corin. I will take the three fish. There is room for you at the table when your work is done.','Fresh from the water. Thank you, Corin. These will do nicely for supper.']),
'fish_promise':('fisherman',['Garrick needs fish. I will take this catch to the Marsh Hall before I cast again.','Enough for a basket. I promised the tavern a catch, and I mean to keep that promise.']),
'fish_work':('fisherman',['A little patience. Watch the water, not the end of the rod.','There is a good current along this quay. Let us see what it brings.']),
'rest':('fisherman',['A moment off my feet, then back to the water.','The tide can wait while I catch my breath.']),
'courier_report':('elowen',['Osric, the bread reached Garrick safely. Lysa\'s basket is in the kitchen now.']),
'report_ack':('crier',['Thank you, Elowen. I will let the square know when the next notice is due.']),
'social_hello':('resident_living',['Good day, Elowen. You look as though you have crossed every bridge in Vesper.','Elowen! Is there a quiet table at the Marsh Hall today?']),
'social_reply':('elowen',['More than a few bridges, Nessa. A warm meal will be welcome.','Garrick will find you a place. I am hoping to stop there myself.']),
'meal_order':('resident_living',['Garrick, may I have a little fish and bread? The walk has given me an appetite.']),
'meal_served':('barkeep',['Here you are, Nessa. Fresh fish and Lysa\'s bread. Take your time with it.']),
'meal_thanks':('resident_living',['That was just what I needed. Please thank the people who brought it in.']),
'meal_empty':('barkeep',['I am waiting for supplies before I can serve that. Give me a little time.']),
'baking':('baker',['Another batch ready. There is nothing like the smell of a warm oven.','A little flour on the sleeves is the mark of an honest morning.']),
'greet_crier':('crier',['Good day. Ask me for news, services, or work. I only report what has reached my ears.']),
'greet_fisherman':('fisherman',['Good day. I fish these quays and bring part of my catch to Garrick. Ask about work if you want to help.']),
'greet_barkeep':('barkeep',['Welcome to the Marsh Hall. I buy fresh fish for three gold each. There is always work in keeping a kitchen supplied.']),
'greet_baker':('baker',['Welcome to the Twisted Oven. A warm loaf is two gold. Elowen sometimes carries a basket over to the tavern for me.']),
'greet_elowen':('elowen',['Good to see you. Between museum deliveries and errands for the neighbours, there is always another bridge to cross.']),
'greet_resident_living':('resident_living',['I am Nessa. I mend nets when there is work, and visit the Marsh Hall when my stomach insists.']),
'greet_banker':('banker',['Welcome to the Mint. Say bank nearby, and I will open your box. Your valuables remain yours.']),
'greet_joiner':('joiner',['Good timber deserves careful hands. What brings you to my workshop?']),
'greet_shipwright':('shipwright',['Mind your step in the yard. We have boats on the water and work on the bench.']),
'greet_curator':('curator',['Welcome to Vesper Museum. Our city trades in many things, but memory is what we keep here.']),
'greet_innkeeper':('innkeeper',['Welcome to the Ironwood Inn. Rest a while. The bridges will still be here when you are ready.']),
'greet_healer':('healer',['Take a breath, traveller. There is no charge for a little kindness.']),
'player_help':('barkeep',['Bring one fish back here and say deliver fish. I will pay three gold when it is handed over.']),
'player_accept':('barkeep',['Then we have an agreement. One fish for the kitchen, three gold for your trouble. Come back when you have it.']),
'player_delivered':('barkeep',['A fish for the kitchen, and three gold for you. Thank you for keeping your word.']),
'player_no_fish':('barkeep',['You have not brought a fish yet. Corin can show you where to cast a line.']),
'player_no_promise':('barkeep',['We have no delivery arranged yet. Ask about work, or use vendor sell to sell your catch.']),
'player_remember':('barkeep',['I remember your delivery. A kitchen runs on people who keep their word.']),
'player_waiting':('barkeep',['I am still waiting for the fish you promised. No hurry; bring it when you have a catch.']),
'unknown':('crier',['That is beyond my news today. Ask about news, services, or work, and I will help where I can.']),
'work_direction':('crier',['Ask Garrick at the Marsh Hall about work. He can offer a small fish delivery when the kitchen needs help.']),
'no_news':('crier',['No fresh notice has reached me just now. I will speak when there is something worth sharing.']),
'thanks':('elowen',['You are welcome. A little help makes these bridges feel shorter.'])
}
# Each citizen has occupational lines and neutral replies that can be combined
# only when two people actually meet. These are authored, not generated chat.
NEIGHBOUR_VOICES=['bm_fable','bf_emma','bm_daniel','af_heart','bm_george','am_michael','bf_isabella','bm_fable','bf_emma']
NEIGHBOUR_LINES=[
("Rowan", "I copy the museum notices. A misplaced date can start a very old argument.", "There is always another story to bring home."),
("Wren", "Salt gets into everything by the canals. Even the cloth needs a little care.", "Good company makes a long day shorter."),
("Hobb", "I am learning a tune for the tavern. Best give me another week before you listen.", "I will remember that next time I cross the square."),
("Mira", "Keep a little room on the bridge. We all reach the other side faster that way.", "Take care on your way. I will keep an eye on this crossing."),
("Oren", "I came here to mend books. I may stay for the view from the bridges.", "A town is better when its people have time for one another."),
("Jory", "A sound hull starts with sound timber. Maren checks every plank I bring.", "I had better keep moving. These parcels do not carry themselves."),
("Tessa", "I make pots for people who use them. The prettiest one still needs to hold water.", "That sounds like a good reason to stop at the tavern."),
("Bram", "Sella keeps a careful inn. Clean linen, warm water, and remedies within reach.", "I will see you again when my errands are done."),
("Ada", "I mend clocks, but Vesper seems to run on tides and gossip.", "A moment to talk is time well spent.")]
for i,(name,line,reply) in enumerate(NEIGHBOUR_LINES):
    speaker=f'neighbour_{i}'
    VOICES[speaker]=NEIGHBOUR_VOICES[i]
    LINES['greet_'+speaker]=(speaker,[f'I am {name}. '+line])
    LINES['chat_'+speaker]=(speaker,[line,reply])
    LINES['reply_'+speaker]=(speaker,[reply,'Good to see you. Safe travels across the bridges.'])
OCCUPATIONS={
 'crier':('News travels on feet in this town. Bring me facts, and I will give them a voice.','Thank you for stopping. I keep an ear open for the neighbours.'),
 'fisherman':('The water teaches patience. The kitchen teaches you not to waste a catch.','Good company, and a little luck with the tide. That is enough for me.'),
 'elowen':('Every errand is another reason to cross a bridge. I am getting to know them all.','I will look in again when my deliveries are finished.'),
 'barkeep':('A warm table takes more than a fire. Someone has to bring the fish and bread.','Come back when you have a moment. There is always company at the Marsh Hall.'),
 'baker':('People say bread brings a town together. I think they mostly mean the smell.','Take care on the bridges. And do not forget to eat.'),
 'banker':('I count coins all morning. It is good to see a familiar face between the figures.','Your bank box will be here when you need it.'),
 'joiner':('A plank is a promise. It may become a chair, or carry someone safely over the sea.','Bring it by the workshop if it needs mending.'),
 'shipwright':('A boat is a thousand small jobs. Miss one, and the sea will find it.','Safe steps on the quay. The water gives no second warning.'),
 'healer':('Rest and a warm meal do more good than most people allow themselves.','Look after yourself. Vesper has time for kindness.'),
 'innkeeper':('Travellers bring stories with their muddy boots. I could listen all evening.','There is a welcome at the Ironwood when your day is done.'),
 'curator':('The smallest objects can tell the longest stories. That is why I keep them.','Call at the museum when you have a quiet hour.'),
 'resident_living':('Mending nets is patient work. A good knot is worth doing twice.','Perhaps I will see you at the tavern later.')}
for speaker,(line,reply) in OCCUPATIONS.items():
    LINES['chat_'+speaker]=(speaker,[line,reply])
    LINES['reply_'+speaker]=(speaker,[reply])
    LINES['friend_'+speaker]=(speaker,['Good to see you again. I remember your help. People who keep their word are welcome here.'])
LINES.update({
 'timber_collect':('neighbour_5',['Tomas, I have come for three planks for Maren. I will take them straight to the boatyard.']),
 'timber_give':('joiner',['Three planks, dry and sound. Mind the ends when you cross the bridges.']),
 'timber_arrival':('neighbour_5',['Maren, here is the timber from Tomas. Three planks, and all of them dry.']),
 'timber_thanks':('shipwright',['Thank you, Jory. That is timber I can put to work.']),
 'remedies_collect':('neighbour_7',['Anwen, Sella asked for two jars for the inn. I will carry them carefully.']),
 'remedies_give':('healer',['Here are the two jars. Keep the lids closed and tell Sella they are ready.']),
 'remedies_arrival':('neighbour_7',['Sella, the remedies have arrived. Two jars from Anwen, safely carried.']),
 'remedies_thanks':('innkeeper',['Thank you, Bram. I will keep them ready for our guests.']),
 'timber_news':('crier',['Word from the boatyard. Jory has delivered timber from Tomas to Maren. Another errand safely done.']),
 'remedies_news':('crier',["News from the Ironwood Inn. Bram has brought Anwen's remedies to Sella. The jars arrived safely."]),
 'parcel_accept':('joiner',['Take this plank to Maren at the Majestic Boat. Say deliver parcel when you arrive. Five gold for a careful delivery.']),
 'parcel_delivered':('shipwright',['The plank is sound. Here are five gold, and my thanks for carrying it.']),
 'friend_supper':('barkeep',['You have helped the neighbours. Let us do something for you. Fish and bread, on the house. Pull up a chair.'])
})

def main():
    out=ROOT/'godot/assets/voices';out.mkdir(exist_ok=True)
    engine=SpeechEngine(ROOT/'helper/models');catalog={};metrics=[]
    for topic,(speaker,lines) in LINES.items():
        catalog[topic]=[]
        for index,text in enumerate(lines):
            name=f'{topic}_{index}';file=out/(name+'.wav')
            if not file.exists():
                stats=engine.render(text,VOICES[speaker],file);metrics.append({'id':name,**stats});print(name,stats,flush=True)
            catalog[topic].append({'id':name,'speaker':speaker,'text':text,'voice':VOICES[speaker],'file':'res://assets/voices/'+name+'.wav'})
    target=ROOT/'godot/data';target.mkdir(exist_ok=True)
    (target/'voice_catalog.json').write_text(json.dumps(catalog,indent=2),encoding='utf-8')
    (ROOT/'docs/voice-generation.json').write_text(json.dumps(metrics,indent=2))
if __name__=='__main__':main()
