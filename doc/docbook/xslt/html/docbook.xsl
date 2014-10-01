<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:import
    href="http://docbook.sourceforge.net/release/xsl/current/html/docbook.xsl"/>

  <xsl:output encoding="utf-8"/>
  <xsl:include href="sections.xsl"/>
  <xsl:include href="formal.xsl"/>

 <!-- Name of the stylesheet(s) to use in the generated HTML  -->
 <xsl:param name="html.stylesheet">susebooks.css</xsl:param>
  
 <!-- Output NAME header before refnames?                     -->
 <xsl:param name="refentry.generate.name" select="0"/>

 <!-- Output title before refnames?                           --> 
 <xsl:param name="refentry.generate.title" select="1"/>

 <!-- No index for HTML                                       -->
 <xsl:param name="generate.index" select="0"/>
 
 <!-- Are sections enumerated?                                -->
 <xsl:param name="section.autolabel" select="1"/>
  
 <!-- Do section labels include the component label?          -->
 <xsl:param name="section.label.includes.component.label" select="1"/>

 <!-- Output permalinks?                                      -->
 <xsl:param name="generate.permalink" select="1"/>

</xsl:stylesheet>
