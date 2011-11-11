<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version="1.0">
  
  <xsl:output method="text"/>
  
  <xsl:key name="elements" match="*" use="local-name()"/>
  
  <xsl:template match="*"/>
  
  
  <xsl:template match="/">
    <xsl:text>Summary of elements:&#10;</xsl:text>
    <xsl:for-each select="//*[generate-id(.) = 
                              generate-id(key('elements',local-name())[1])]">
      <xsl:sort select="local-name()"/>
      <xsl:for-each select="key('elements',local-name())">
        <xsl:if test="position() = 1">
          <xsl:text>Element </xsl:text>
          <xsl:value-of select="local-name()"/>
          <xsl:text> = </xsl:text>
          <xsl:value-of select="count(//*[name() = name(current())])"/>
          <xsl:text>&#10;</xsl:text>
        </xsl:if>
      </xsl:for-each>
    </xsl:for-each>
    <xsl:text>&#10;Total: </xsl:text>
    <xsl:value-of select="count(//*)"/>
    <xsl:text> elements&#10;</xsl:text>
  </xsl:template>
  
</xsl:stylesheet>