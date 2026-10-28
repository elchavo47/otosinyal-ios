import 'dart:math' as math;
import 'package:flutter/material.dart';

class CircularGauge extends StatelessWidget {
  final double value, maxValue, size;
  final String label, unit;
  final Color color, trackColor;
  final int fractionDigits;
  const CircularGauge({super.key,required this.value,required this.maxValue,required this.label,required this.unit,required this.color,required this.trackColor,this.fractionDigits=0,this.size=170});
  @override Widget build(BuildContext context){
    final progress=(value/maxValue).clamp(0.0,1.0);
    return TweenAnimationBuilder<double>(tween:Tween(begin:0,end:progress),duration:const Duration(milliseconds:450),curve:Curves.easeOutCubic,builder:(context,p,_)=>SizedBox(width:size,height:size,child:CustomPaint(painter:_GaugePainter(progress:p,color:color,trackColor:trackColor),child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      SizedBox(height:size*.12),
      TweenAnimationBuilder<double>(tween:Tween(begin:0,end:value),duration:const Duration(milliseconds:450),builder:(_,v,__)=>Text(v.toStringAsFixed(fractionDigits),style:TextStyle(fontFamily:'Inter',fontSize:size*.21,fontWeight:FontWeight.w800,color:Colors.white,height:1))),
      Text(unit.toUpperCase(),style:TextStyle(fontSize:size*.065,fontWeight:FontWeight.w700,color:Colors.white60,letterSpacing:1)),
      SizedBox(height:size*.025),Text(label.toUpperCase(),style:TextStyle(fontSize:size*.062,fontWeight:FontWeight.w800,color:color,letterSpacing:1.7)),
    ])))));
  }
}
class _GaugePainter extends CustomPainter{
  final double progress; final Color color,trackColor; _GaugePainter({required this.progress,required this.color,required this.trackColor});
  static const start=140.0,sweep=260.0;
  @override void paint(Canvas c,Size s){final center=Offset(s.width/2,s.height/2),r=math.min(s.width,s.height)/2-12,sa=start*math.pi/180,sw=sweep*math.pi/180;
    final glow=Paint()..color=color.withValues(alpha:.16)..style=PaintingStyle.stroke..strokeWidth=s.width*.105..strokeCap=StrokeCap.round..maskFilter=const MaskFilter.blur(BlurStyle.normal,8);
    if(progress>0)c.drawArc(Rect.fromCircle(center:center,radius:r),sa,sw*progress,false,glow);
    final track=Paint()..color=trackColor..style=PaintingStyle.stroke..strokeWidth=s.width*.055..strokeCap=StrokeCap.round;c.drawArc(Rect.fromCircle(center:center,radius:r),sa,sw,false,track);
    final val=Paint()..style=PaintingStyle.stroke..strokeWidth=s.width*.06..strokeCap=StrokeCap.round..shader=SweepGradient(transform:GradientRotation(sa),colors:[color.withValues(alpha:.35),color,color]).createShader(Rect.fromCircle(center:center,radius:r));if(progress>0)c.drawArc(Rect.fromCircle(center:center,radius:r),sa,sw*progress,false,val);
    final tick=Paint()..strokeCap=StrokeCap.round;for(int i=0;i<=26;i++){final a=sa+sw*i/26,major=i%5==0;tick..color=(i/26<=progress?color:Colors.white24)..strokeWidth=major?2:1;final outer=r-10,inner=outer-(major?8:4);c.drawLine(center+Offset(math.cos(a)*inner,math.sin(a)*inner),center+Offset(math.cos(a)*outer,math.sin(a)*outer),tick);}
    final needleA=sa+sw*progress,needle=Paint()..color=Colors.white70..strokeWidth=1.6..strokeCap=StrokeCap.round;c.drawLine(center,center+Offset(math.cos(needleA)*(r*.54),math.sin(needleA)*(r*.54)),needle);c.drawCircle(center,4,Paint()..color=color);
  }
  @override bool shouldRepaint(covariant _GaugePainter o)=>o.progress!=progress||o.color!=color||o.trackColor!=trackColor;
}
