<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml"
	indent="yes" omit-xml-declaration="no" encoding="utf-8"/>
<xsl:strip-space elements="type"/>

<!-- default rule -->
<xsl:template match="*|processing-instruction()|comment()" mode="conv44to45">
	<xsl:copy>
		<xsl:copy-of select="@*"/>
		<xsl:apply-templates mode="conv44to45"/>
	</xsl:copy>
</xsl:template>

<!-- update schema version -->
<para xmlns="http://docbook.org/ns/docbook">
	Changed attribute <tag class="attribute">schemaversion</tag>
	to <tag class="attribute">schemaversion</tag> from
	<literal>4.4</literal> to <literal>4.5</literal>.
</para>
<xsl:template match="image" mode="conv44to45">
	<image schemaversion="4.5">
		<xsl:copy-of select="@*[local-name() != 'schemaversion']"/>
		<xsl:apply-templates mode="conv44to45"/>
	</image>
</xsl:template>

<!-- remove compressed element -->
<para xmlns="http://docbook.org/ns/docbook">
	Remove patternPackageType attribute, it's no longer used
</para>
<xsl:template match="packages" mode="conv44to45">
	<packages>
	<xsl:copy-of select="@*[not(local-name(.) = 'patternPackageType')]"/>
	<xsl:apply-templates mode="conv44to45"/>
	</packages>
</xsl:template>

</xsl:stylesheet>
